require "net/http"

# Sends portal notifications as email through KRAI mail endpoints, one GET request per
# recipient, in the same style as papl_jj_payment_notify.aspx:
#
#   Guest House: https://krai.asaindia.org/kra_guest_house_notify.aspx  (KRAI_GUEST_HOUSE_NOTIFY_URL)
#   Help Desk:   https://krai.asaindia.org/kra_helpdesk_notify.aspx     (KRAI_HELP_DESK_NOTIFY_URL)
#
# Every request carries to_email, to_name, subject, message, the module's own fields,
# updated_on, updated_by, test_mode and actual_email. Set KRAI_NOTIFY_TEST_EMAIL to send
# every mail to that address instead (test_mode=1, real address in actual_email).
#
# Requests run in a background thread and never raise, so a mail problem can never
# break the booking / ticket action that triggered it. Sending is on in production;
# elsewhere set IT_TOOL_NOTIFICATIONS=1, otherwise requests are only logged and
# recorded in .deliveries.
class ItToolNotification
  ENDPOINTS = {
    guest_house: ENV.fetch("KRAI_GUEST_HOUSE_NOTIFY_URL", "https://krai.asaindia.org/kra_guest_house_notify.aspx"),
    help_desk: ENV.fetch("KRAI_HELP_DESK_NOTIFY_URL", "https://krai.asaindia.org/kra_helpdesk_notify.aspx")
  }.freeze
  TIME_ZONE = "Asia/Kolkata".freeze

  class << self
    attr_writer :enabled

    def deliveries
      @deliveries ||= []
    end

    def enabled?
      return @enabled unless @enabled.nil?

      Rails.env.production? || ENV["IT_TOOL_NOTIFICATIONS"] == "1"
    end

    def test_email
      ENV["KRAI_NOTIFY_TEST_EMAIL"].presence
    end

    # module_name: :guest_house or :help_desk
    # recipients: a User, an email, { email:, name: }, or a list of these.
    # fields: the module's own parameters (sent in the order given).
    def deliver(module_name:, recipients:, subject:, message:, fields: {}, updated_by: nil)
      endpoint = ENDPOINTS.fetch(module_name.to_sym)
      normalize(recipients).each do |recipient|
        params = {
          to_email: test_email || recipient[:email],
          to_name: recipient[:name],
          subject: subject,
          message: message
        }.merge(fields).merge(
          updated_on: format_time(Time.current),
          updated_by: updated_by.presence || "System",
          test_mode: test_email ? 1 : 0,
          actual_email: test_email ? recipient[:email] : nil
        )
        send_request(endpoint, params)
      end
    rescue StandardError => e
      Rails.logger.error("[ItToolNotification] #{subject}: #{e.class}: #{e.message}")
    end

    def url_for(endpoint, params)
      "#{endpoint}?#{URI.encode_www_form(params.transform_values { |value| value.to_s })}"
    end

    def format_date(value)
      value.presence && value.to_date.strftime("%d/%m/%Y")
    end

    def format_time(value)
      value.presence && value.in_time_zone(TIME_ZONE).strftime("%d/%m/%Y %I:%M %p")
    end

    def format_amount(value)
      format("%.2f", value.to_d) unless value.nil?
    end

    private

    def normalize(recipients)
      Array(recipients).filter_map do |recipient|
        email, name = case recipient
                      when User then [ recipient.email, recipient.display_name ]
                      when Hash then [ recipient[:email], recipient[:name] ]
                      else
                        user = User.find_by("LOWER(email) = ?", recipient.to_s.strip.downcase)
                        [ recipient, user&.display_name ]
                      end
        email = email.to_s.strip
        next if email.blank?

        { email: email, name: name.presence || email }
      end.uniq { |recipient| recipient[:email].downcase }
    end

    def send_request(endpoint, params)
      url = url_for(endpoint, params)
      unless enabled?
        deliveries << params.merge(endpoint: endpoint)
        Rails.logger.info("[ItToolNotification] (not sent, disabled) #{params[:subject]} -> #{params[:to_email]}")
        return
      end

      Thread.new do
        uri = URI(url)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 20) do |http|
          http.get(uri.request_uri)
        end
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error("[ItToolNotification] #{params[:subject]} -> #{params[:to_email]} failed: HTTP #{response.code}")
        end
      rescue StandardError => e
        Rails.logger.error("[ItToolNotification] #{params[:subject]} -> #{params[:to_email]} failed: #{e.class}: #{e.message}")
      end
    end
  end
end
