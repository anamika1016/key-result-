class CreateSystemSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :system_settings do |t|
      t.string :key
      t.string :value

      t.timestamps
    end
    add_index :system_settings, :key
  end
end
