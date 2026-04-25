class UpdateUserQuizzesForManualEntryAndImport < ActiveRecord::Migration[8.0]
  def change
    change_column_null :user_quizzes, :user_id, true
    change_column_null :user_quizzes, :quiz_id, true

    add_column :user_quizzes, :password, :string
  end
end
