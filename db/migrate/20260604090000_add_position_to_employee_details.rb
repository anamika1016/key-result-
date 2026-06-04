class AddPositionToEmployeeDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :employee_details, :position, :string
  end
end
