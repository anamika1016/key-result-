require "net/http"

# Sends portal notifications as email through the KRAI mail endpoint
# (https://krai.asaindia.org/it-tool_notification.aspx), one request per recipient.
#
# Requests run in a background thread and never raise, so a mail problem can never
# break the booking / ticket action that triggered it.
#
# Sending is on in production. Elsewhere set IT_TOOL_NOTIFICATIONS=1 to send for real;
# otherwise requests are only logged (and recorded in .deliveries for checks).
class ItToolNotification
  ENDPOINT = ENV.fetch("IT_TOOL_NOTIFICATION_URL", "https://krai.asaindia.org/it-tool_notification.aspx")
  MAIL_TYPE = "portal_notification".freeze

  class << self
    attr_writer :enabled

    def deliveries
      @deliveries ||= []
    end

    def enabled?
      return @enabled unless @enabled.nil?

      Rails.env.production? || ENV["IT_TOOL_NOTIFICATIONS"] == "1"
    end

    # recipients: [{ email:, name: }] or a User or a list of Users / emails.
    def deliver(recipients:, subject:, message:, link: nil, action: nil, remarks: nil, employee_name: nil, employee_code: nil)
      normalize(recipients).each do |recipient|
        params = {
          to_email: recipient[:email],
          to_name: recipient[:name],
          subject: subject,
          message: message,
          link: link,
          employee_name: employee_name,
          employee_code: employee_code,
          quarter: nil,
          month: nil,
          reviewer_role: nil,
          reviewer_name: nil,
          action: action,
          remarks: remarks,
          mail_type: MAIL_TYPE
        }
        send_request(params)
      end
    rescue StandardError => e
      Rails.logger.error("[ItToolNotification] #{subject}: #{e.class}: #{e.message}")
    end

    def url_for(params)
      "#{ENDPOINT}?#{URI.encode_www_form(params.transform_values { |value| value.to_s })}"
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

    def send_request(params)
      url = url_for(params)
      unless enabled?
        deliveries << params
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
