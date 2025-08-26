class RemoveUniqueIndexFromAchievements < ActiveRecord::Migration[8.0]
  def change
    remove_index :achievements, name: "index_achievements_on_user_detail_id_and_month"
    add_index :achievements, [:user_detail_id, :month] # non-unique
  end
end
