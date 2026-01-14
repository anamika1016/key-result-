class AddCounterCacheColumns < ActiveRecord::Migration[8.0]
  def change
    # Add counter cache for user_details count on employee_details
    add_column :employee_details, :user_details_count, :integer, default: 0, null: false

    # Add counter cache for achievements count on user_details
    add_column :user_details, :achievements_count, :integer, default: 0, null: false

    # Add counter cache for activities count on departments
    add_column :departments, :activities_count, :integer, default: 0, null: false

    # Reset all counter cache columns
    reversible do |dir|
      dir.up do
        # Reset counter caches manually
        EmployeeDetail.find_each do |employee|
          EmployeeDetail.reset_counters(employee.id, :user_details)
        end

        UserDetail.find_each do |user_detail|
          UserDetail.reset_counters(user_detail.id, :achievements)
        end

        Department.find_each do |department|
          Department.reset_counters(department.id, :activities)
        end
      end
    end
  end
end
