class RemoveEmployeeIdFromEmployeeDetails < ActiveRecord::Migration[8.0]
  def change
    remove_column :employee_details, :employee_id, :string
  end
end
