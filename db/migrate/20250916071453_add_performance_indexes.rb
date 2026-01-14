class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Indexes for employee_details commonly queried fields
    add_index :employee_details, :employee_email unless index_exists?(:employee_details, :employee_email)
    add_index :employee_details, :employee_code unless index_exists?(:employee_details, :employee_code)
    add_index :employee_details, :l1_code unless index_exists?(:employee_details, :l1_code)
    add_index :employee_details, :l2_code unless index_exists?(:employee_details, :l2_code)
    add_index :employee_details, :l3_code unless index_exists?(:employee_details, :l3_code)
    add_index :employee_details, :status unless index_exists?(:employee_details, :status)

    # Composite index for common L1/L2 queries
    add_index :employee_details, [ :l1_code, :status ] unless index_exists?(:employee_details, [ :l1_code, :status ])
    add_index :employee_details, [ :l2_code, :status ] unless index_exists?(:employee_details, [ :l2_code, :status ])
    add_index :employee_details, [ :l3_code, :status ] unless index_exists?(:employee_details, [ :l3_code, :status ])

    # Indexes for achievements table
    add_index :achievements, :status unless index_exists?(:achievements, :status)
    add_index :achievements, :month unless index_exists?(:achievements, :month)
    add_index :achievements, [ :user_detail_id, :month ] unless index_exists?(:achievements, [ :user_detail_id, :month ])
    add_index :achievements, [ :user_detail_id, :status ] unless index_exists?(:achievements, [ :user_detail_id, :status ])
    add_index :achievements, [ :status, :month ] unless index_exists?(:achievements, [ :status, :month ])

    # Indexes for user_details table
    add_index :user_details, :employee_detail_id unless index_exists?(:user_details, :employee_detail_id)
    add_index :user_details, [ :employee_detail_id, :department_id ] unless index_exists?(:user_details, [ :employee_detail_id, :department_id ])

    # Indexes for users table
    add_index :users, :employee_code unless index_exists?(:users, :employee_code)
    add_index :users, :role unless index_exists?(:users, :role)

    # Indexes for departments table
    add_index :departments, :department_type unless index_exists?(:departments, :department_type)

    # Index for SMS logs
    add_index :sms_logs, [ :employee_detail_id, :quarter ] unless index_exists?(:sms_logs, [ :employee_detail_id, :quarter ])
  end
end
