class CreateNavItems < ActiveRecord::Migration[8.0]
  def change
    create_table :nav_items do |t|
      t.references :nav_menu, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :nav_items }
      t.string :label
      t.string :url
      t.references :entry, foreign_key: true
      t.integer :position

      t.timestamps
    end
  end
end
