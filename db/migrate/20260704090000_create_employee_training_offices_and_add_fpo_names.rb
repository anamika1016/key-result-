class CreateEmployeeTrainingOfficesAndAddFpoNames < ActiveRecord::Migration[8.0]
  def change
    create_table :employee_training_offices do |t|
      t.string :office_type, null: false
      t.string :office_name
      t.string :fpo_name
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :employee_training_offices, :office_type
    add_index :employee_training_offices, [ :office_type, :office_name ]
    add_index :employee_training_offices, [ :office_type, :fpo_name ]

    add_column :employee_trainings, :fpo_names, :jsonb, null: false, default: []
  end
end
