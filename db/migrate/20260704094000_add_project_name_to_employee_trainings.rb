class AddProjectNameToEmployeeTrainings < ActiveRecord::Migration[8.0]
  def change
    create_table :employee_training_projects do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :employee_training_projects, :name, unique: true
    add_index :employee_training_projects, :active

    add_column :employee_trainings, :project_name, :string
    add_index :employee_trainings, :project_name
  end
end
