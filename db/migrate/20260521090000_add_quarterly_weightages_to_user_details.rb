class AddQuarterlyWeightagesToUserDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :user_details, :total_weightage, :decimal, precision: 8, scale: 2
    add_column :user_details, :weightage_q1, :decimal, precision: 8, scale: 2
    add_column :user_details, :weightage_q2, :decimal, precision: 8, scale: 2
    add_column :user_details, :weightage_q3, :decimal, precision: 8, scale: 2
    add_column :user_details, :weightage_q4, :decimal, precision: 8, scale: 2
  end
end
