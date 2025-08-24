class RemoveUserDetailIdFromSmsLogs < ActiveRecord::Migration[8.0]
  def change
    remove_reference :sms_logs, :user_detail, foreign_key: true
  end
end
