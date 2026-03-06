class SmsService
  include HTTParty

  BASE_URL = "https://sms.yoursmsbox.com/api/sendhttp.php"
  AUTH_KEY = "3230666f72736131353261"
  SENDER = "ACTFSA"
  ROUTE = "2"
  COUNTRY = "0"
  DLT_TE_ID = "1707175983185179621"
  UNICODE = "1"

  def self.send_sms(mobile_number, message)
    return { success: false, message: "Mobile number is required" } if mobile_number.blank?
    return { success: false, message: "Message is required" } if message.blank?

    begin
      # Clean mobile number (remove any non-digit characters except +)
      clean_mobile = mobile_number.gsub(/[^\d+]/, "")

      # Remove leading + if present
      clean_mobile = clean_mobile.gsub(/^\+/, "")

      # Use the mobile number as-is (like Chrome) - don't add country code
      # The API seems to work better without the country code prefix
      if clean_mobile.length == 10 && clean_mobile.match?(/^[6-9]\d{9}$/)
        # Keep as 10-digit number (like Chrome)
        Rails.logger.info "Using 10-digit mobile number: #{clean_mobile}"
      elsif clean_mobile.length == 12 && clean_mobile.start_with?("91")
        # Remove country code to match Chrome format
        clean_mobile = clean_mobile[2..-1]
        Rails.logger.info "Removed country code, using: #{clean_mobile}"
      else
        Rails.logger.error "Invalid mobile number format: #{mobile_number}"
        return { success: false, message: "Invalid mobile number format" }
      end

      # URL encode the message
      encoded_message = URI.encode_www_form_component(message)

      # Build the API URL
      url = "#{BASE_URL}?authkey=#{AUTH_KEY}&mobiles=#{clean_mobile}&message=#{encoded_message}&sender=#{SENDER}&route=#{ROUTE}&country=#{COUNTRY}&DLT_TE_ID=#{DLT_TE_ID}&unicode=#{UNICODE}"

      Rails.logger.info "Sending SMS to #{clean_mobile}: #{message}"

      # Make the HTTP request
      response = HTTParty.get(url, timeout: 30)

      Rails.logger.info "SMS API Response: #{response.body}"

      # Parse the response
      if response.success?
        response_body = response.body.strip

        # Check if the response indicates success
        # The API typically returns a message ID on success or an error message on failure
        if response_body.match?(/^\d+$/) || response_body.downcase.include?("success")
          Rails.logger.info "SMS sent successfully to #{clean_mobile}"
          { success: true, message: "SMS sent successfully", response: response_body }
        else
          Rails.logger.error "SMS API returned error: #{response_body}"
          { success: false, message: "SMS API error: #{response_body}" }
        end
      else
        Rails.logger.error "SMS API HTTP error: #{response.code} - #{response.message}"
        { success: false, message: "SMS API HTTP error: #{response.code}" }
      end

    rescue => e
      Rails.logger.error "SMS sending failed: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      { success: false, message: "SMS sending failed: #{e.message}" }
    end
  end

  # SMS message templates
  def self.submission_message(employee_name, quarter)
    "Emp-Name: #{employee_name} has submitted his #{quarter} KRA MIS. Please review and approve in the system. Action For Social Advancement (ASA)"
  end

  def self.l1_approval_message(employee_name, quarter)
    "Your #{quarter} KRA MIS has been approved by L1 Manager. Action For Social Advancement (ASA)"
  end

  def self.l1_return_message(employee_name, quarter)
    "Your #{quarter} KRA MIS has been returned by L1 Manager for revision. Please check and resubmit. Action For Social Advancement (ASA)"
  end

  def self.l2_approval_message(employee_name, quarter)
    "Your #{quarter} KRA MIS has been approved by L2 Manager. Action For Social Advancement (ASA)"
  end

  def self.l2_return_message(employee_name, quarter)
    "Your #{quarter} KRA MIS has been returned by L2 Manager for revision. Please check and resubmit. Action For Social Advancement (ASA)"
  end

  def self.l3_approval_message(employee_name, quarter)
    "Your #{quarter} KRA MIS has been finally approved by L3 Manager. Action For Social Advancement (ASA)"
  end

  def self.l3_return_message(employee_name, quarter)
    "Your #{quarter} KRA MIS has been returned by L3 Manager for revision. Please check and resubmit. Action For Social Advancement (ASA)"
  end

  def self.l2_notification_message(employee_name, quarter)
    "#{employee_name}'s #{quarter} KRA MIS has been approved by L1 and is pending your review. Action For Social Advancement (ASA)"
  end

  def self.l3_notification_message(employee_name, quarter)
    "#{employee_name}'s #{quarter} KRA MIS has been approved by L2 and is pending your review. Action For Social Advancement (ASA)"
  end

  def self.l1_notification_message(employee_name, quarter, action)
    action_text = action == "approved" ? "approved" : "returned"
    "#{employee_name}'s #{quarter} KRA MIS has been #{action_text} by L2 Manager. Action For Social Advancement (ASA)"
  end

  def self.l2_notification_message_for_l3(employee_name, quarter, action)
    action_text = action == "approved" ? "approved" : "returned"
    "#{employee_name}'s #{quarter} KRA MIS has been #{action_text} by L3 Manager. Action For Social Advancement (ASA)"
  end
end
