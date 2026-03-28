class ConvertYearColumnsToFinancialYearStrings < ActiveRecord::Migration[8.0]
  class MigrationUserDetail < ApplicationRecord
    self.table_name = "user_details"
  end

  class MigrationActivity < ApplicationRecord
    self.table_name = "activities"
  end

  def up
    convert_year_column(
      :user_details,
      MigrationUserDetail,
      composite_index: [ :employee_detail_id, :department_id, :activity_id, :year ],
      composite_name: "index_user_details_on_employee_department_activity_year"
    )

    convert_year_column(
      :activities,
      MigrationActivity,
      composite_index: [ :department_id, :activity_name, :theme_name, :year ],
      composite_name: "index_activities_on_department_activity_theme_year"
    )
  end

  def down
    revert_year_column(
      :user_details,
      MigrationUserDetail,
      composite_index: [ :employee_detail_id, :department_id, :activity_id, :year ],
      composite_name: "index_user_details_on_employee_department_activity_year"
    )

    revert_year_column(
      :activities,
      MigrationActivity,
      composite_index: [ :department_id, :activity_name, :theme_name, :year ],
      composite_name: "index_activities_on_department_activity_theme_year"
    )
  end

  private

  def convert_year_column(table_name, model_class, composite_index:, composite_name:)
    return unless column_exists?(table_name, :year)
    return if columns(table_name).find { |column| column.name == "year" }&.type == :string

    add_column table_name, :financial_year_tmp, :string

    model_class.reset_column_information
    model_class.find_each do |record|
      record.update_columns(financial_year_tmp: to_financial_year_label(record.read_attribute(:year), record.created_at))
    end

    remove_index table_name, :year if index_exists?(table_name, :year)
    remove_index table_name, name: composite_name if index_exists?(table_name, composite_index, name: composite_name)

    remove_column table_name, :year
    rename_column table_name, :financial_year_tmp, :year
    change_column_null table_name, :year, false

    add_index table_name, :year unless index_exists?(table_name, :year)
    add_index table_name, composite_index, name: composite_name unless index_exists?(table_name, composite_index, name: composite_name)
  end

  def revert_year_column(table_name, model_class, composite_index:, composite_name:)
    return unless column_exists?(table_name, :year)
    return if columns(table_name).find { |column| column.name == "year" }&.type == :integer

    add_column table_name, :start_year_tmp, :integer

    model_class.reset_column_information
    model_class.find_each do |record|
      record.update_columns(start_year_tmp: to_start_year(record.read_attribute(:year), record.created_at))
    end

    remove_index table_name, :year if index_exists?(table_name, :year)
    remove_index table_name, name: composite_name if index_exists?(table_name, composite_index, name: composite_name)

    remove_column table_name, :year
    rename_column table_name, :start_year_tmp, :year
    change_column_null table_name, :year, false

    add_index table_name, :year unless index_exists?(table_name, :year)
    add_index table_name, composite_index, name: composite_name unless index_exists?(table_name, composite_index, name: composite_name)
  end

  def to_financial_year_label(value, created_at)
    start_year = to_start_year(value, created_at)
    end_year = start_year + 1
    "#{start_year.to_s[-2, 2]}-#{end_year.to_s[-2, 2]}"
  end

  def to_start_year(value, created_at)
    return value if value.is_a?(Integer)

    string_value = value.to_s.strip
    return string_value.to_i if string_value.match?(/\A\d{4}\z/)
    return 2000 + string_value[0, 2].to_i if string_value.match?(/\A\d{2}-\d{2}\z/)
    return string_value[0, 4].to_i if string_value.match?(/\A\d{4}-\d{4}\z/)

    reference_date = created_at || Date.current
    reference_date.month >= 4 ? reference_date.year : reference_date.year - 1
  end
end
