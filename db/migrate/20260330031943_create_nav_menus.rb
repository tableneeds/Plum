class CreateNavMenus < ActiveRecord::Migration[8.0]
  def change
    create_table :nav_menus do |t|
      t.string :name
      t.string :handle

      t.timestamps
    end
    add_index :nav_menus, :handle, unique: true
  end
end
