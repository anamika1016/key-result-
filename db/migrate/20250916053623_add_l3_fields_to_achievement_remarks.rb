class AddL3FieldsToAchievementRemarks < ActiveRecord::Migration[8.0]
  def change
    add_column :achievement_remarks, :l3_remarks, :text
    add_column :achievement_remarks, :l3_percentage, :float
  end
end
