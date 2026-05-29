class CreateGlobals < ActiveRecord::Migration[8.0]
  def change
    create_table :globals do |t|
      t.string :name
      t.string :handle
      t.json :data

      t.timestamps
    end
    add_index :globals, :handle, unique: true
  end
end
