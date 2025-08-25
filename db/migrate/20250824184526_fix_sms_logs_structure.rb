class FixSmsLogsStructure < ActiveRecord::Migration[8.0]
  def up
    # First, add the new column without constraints
    add_reference :sms_logs, :employee_detail, null: true, foreign_key: true
    
    # Update existing records to link to employee_details through user_details
    execute <<-SQL
      UPDATE sms_logs 
      SET employee_detail_id = (
        SELECT employee_detail_id 
        FROM user_details 
        WHERE user_details.id = sms_logs.user_detail_id
      )
      WHERE user_detail_id IS NOT NULL
    SQL
    
    # Remove null values (records that couldn't be linked)
    execute "DELETE FROM sms_logs WHERE employee_detail_id IS NULL"
    
    # Now make the column not null
    change_column_null :sms_logs, :employee_detail_id, false
    
    # Remove the old column
    remove_reference :sms_logs, :user_detail, foreign_key: true
    
    # Add index for better performance
    add_index :sms_logs, [:employee_detail_id, :quarter]
  end

  def down
    # Add back the old column
    add_reference :sms_logs, :user_detail, null: true, foreign_key: true
    
    # Update records back (this is approximate since we lost the exact mapping)
    execute <<-SQL
      UPDATE sms_logs 
      SET user_detail_id = (
        SELECT id 
        FROM user_details 
        WHERE user_details.employee_detail_id = sms_logs.employee_detail_id
        LIMIT 1
      )
    SQL
    
    # Remove the new column
    remove_reference :sms_logs, :employee_detail, foreign_key: true
    
    # Remove the index
    remove_index :sms_logs, [:employee_detail_id, :quarter]
  end
end
