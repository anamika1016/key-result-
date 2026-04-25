class AddUserDetailsToUserQuizzes < ActiveRecord::Migration[8.0]
  def change
    add_column :user_quizzes, :employee_code, :string
    add_column :user_quizzes, :name, :string
    add_column :user_quizzes, :email, :string
    add_column :user_quizzes, :mobile_number, :string
    add_column :user_quizzes, :designation, :string
    add_column :user_quizzes, :branch, :string
    add_column :user_quizzes, :sub_branch, :string
  end
end
