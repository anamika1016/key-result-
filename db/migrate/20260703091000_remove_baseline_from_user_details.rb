class RemoveBaselineFromUserDetails < ActiveRecord::Migration[8.0]
  def change
    remove_column :user_details, :baseline, :text if column_exists?(:user_details, :baseline)
  end
end
