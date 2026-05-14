class StoreQuizDurationInSeconds < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE quizzes
      SET duration = duration * 60
      WHERE duration IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE quizzes
      SET duration = duration / 60
      WHERE duration IS NOT NULL
    SQL
  end
end
