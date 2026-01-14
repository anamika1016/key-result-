class AddQuarterlyColumnsToUserDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :user_details, :q1, :text
    add_column :user_details, :q2, :text
    add_column :user_details, :q3, :text
    add_column :user_details, :q4, :text
  end
end
