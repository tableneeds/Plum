class CreateContentTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :content_types do |t|
      t.string :name
      t.string :handle
      t.boolean :singleton
      t.json :blueprint
      t.string :icon

      t.timestamps
    end
    add_index :content_types, :handle, unique: true
  end
end
