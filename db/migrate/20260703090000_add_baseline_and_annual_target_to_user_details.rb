class AddAnnualTargetToUserDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :user_details, :annual_target, :text
  end
end
