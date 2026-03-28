class AddYearToUserDetails < ActiveRecord::Migration[8.0]
  class MigrationUserDetail < ApplicationRecord
    self.table_name = "user_details"
  end

  def up
    add_column :user_details, :year, :string

    MigrationUserDetail.reset_column_information
    MigrationUserDetail.find_each do |user_detail|
      created_at = user_detail.created_at || Date.current
      start_year = created_at.month >= 4 ? created_at.year : created_at.year - 1
      end_year = start_year + 1
      user_detail.update_columns(year: "#{start_year.to_s[-2, 2]}-#{end_year.to_s[-2, 2]}")
    end

    change_column_null :user_details, :year, false
    add_index :user_details, :year
    add_index :user_details, [ :employee_detail_id, :department_id, :activity_id, :year ], name: "index_user_details_on_employee_department_activity_year"
  end

  def down
    remove_index :user_details, name: "index_user_details_on_employee_department_activity_year"
    remove_index :user_details, :year
    remove_column :user_details, :year
  end
end
