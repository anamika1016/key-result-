class AddQrFieldsToQuizzesAndUserQuizzes < ActiveRecord::Migration[8.0]
  def up
    add_column :quizzes, :qr_token, :string
    add_column :user_quizzes, :submitted_answers, :jsonb, default: {}, null: false
    add_column :user_quizzes, :submitted_at, :datetime

    say_with_time "Backfilling quiz QR tokens" do
      Quiz.reset_column_information
      Quiz.find_each do |quiz|
        quiz.update_columns(qr_token: SecureRandom.urlsafe_base64(10)) if quiz.qr_token.blank?
      end
    end

    add_index :quizzes, :qr_token, unique: true
  end

  def down
    remove_index :quizzes, :qr_token
    remove_column :quizzes, :qr_token
    remove_column :user_quizzes, :submitted_answers
    remove_column :user_quizzes, :submitted_at
  end
end
