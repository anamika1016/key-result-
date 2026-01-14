class RemoveUnusedColumnsFromEmployeeDetails < ActiveRecord::Migration[8.0]
  def change
    remove_column :employee_details, :l1_remarks, :text
    remove_column :employee_details, :l1_percentage, :float
    remove_column :employee_details, :l2_remarks, :text
    remove_column :employee_details, :l2_percentage, :float
  end
end
