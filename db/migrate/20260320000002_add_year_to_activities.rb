class AddYearToActivities < ActiveRecord::Migration[8.0]
  class MigrationActivity < ApplicationRecord
    self.table_name = "activities"
  end

  def up
    add_column :activities, :year, :string

    MigrationActivity.reset_column_information
    MigrationActivity.find_each do |activity|
      created_at = activity.created_at || Date.current
      start_year = created_at.month >= 4 ? created_at.year : created_at.year - 1
      end_year = start_year + 1
      activity.update_columns(year: "#{start_year.to_s[-2, 2]}-#{end_year.to_s[-2, 2]}")
    end

    change_column_null :activities, :year, false
    add_index :activities, :year
    add_index :activities, [ :department_id, :activity_name, :theme_name, :year ], name: "index_activities_on_department_activity_theme_year"
  end

  def down
    remove_index :activities, name: "index_activities_on_department_activity_theme_year"
    remove_index :activities, :year
    remove_column :activities, :year
  end
end
