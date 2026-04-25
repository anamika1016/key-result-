class CreateQuizzes < ActiveRecord::Migration[8.0]
  def change
    create_table :quizzes do |t|
      t.string :title
      t.text :description
      t.integer :duration
      t.string :status

      t.timestamps
    end
  end
end
