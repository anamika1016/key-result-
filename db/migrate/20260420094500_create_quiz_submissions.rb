class CreateQuizSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :quiz_submissions do |t|
      t.references :quiz, null: false, foreign_key: true
      t.references :user_quiz, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :employee_detail, foreign_key: true
      t.string :employee_code, null: false
      t.string :name, null: false
      t.string :email
      t.string :mobile_number
      t.string :designation
      t.string :branch
      t.string :sub_branch
      t.integer :score
      t.string :status, null: false
      t.jsonb :submitted_answers, default: {}, null: false
      t.datetime :submitted_at, null: false

      t.timestamps
    end

    add_index :quiz_submissions, [ :quiz_id, :employee_code ], unique: true
  end
end
