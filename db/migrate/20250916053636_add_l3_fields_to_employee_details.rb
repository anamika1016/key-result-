class AddL3FieldsToEmployeeDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :employee_details, :l3_code, :string
    add_column :employee_details, :l3_employer_name, :string
  end
end
