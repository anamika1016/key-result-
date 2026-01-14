class DropTargetSubmissionsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :target_submissions
  end
end
