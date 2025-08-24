class AddEmployeeDetailIdToSmsLogs < ActiveRecord::Migration[8.0]
  def change
    add_reference :sms_logs, :employee_detail, null: false, foreign_key: true
  end
end
