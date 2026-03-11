class AddReturnToToAchievements < ActiveRecord::Migration[8.0]
  def change
    add_column :achievements, :return_to, :string
  end
end
