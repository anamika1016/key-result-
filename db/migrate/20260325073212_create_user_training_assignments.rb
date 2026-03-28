class CreateUserTrainingAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :user_training_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :training, null: false, foreign_key: true
      t.references :employee_detail, null: false, foreign_key: true

      t.timestamps
    end
  end
end
