class AddProviderFieldsToSmsLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :sms_logs, :mobile_number, :string
    add_column :sms_logs, :provider_status, :string
    add_column :sms_logs, :provider_code, :string
    add_column :sms_logs, :provider_description, :string
    add_column :sms_logs, :message_id, :string
    add_column :sms_logs, :provider_response_raw, :text

    add_index :sms_logs, :message_id
    add_index :sms_logs, :mobile_number
  end
end

