class AddBaselineAndAnnualTargetToUserDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :user_details, :annual_target, :text unless column_exists?(:user_details, :annual_target)
  end
end
