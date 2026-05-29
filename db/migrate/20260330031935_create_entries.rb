class CreateEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :entries do |t|
      t.references :content_type, null: false, foreign_key: true
      t.string :title
      t.string :slug
      t.integer :status
      t.json :data
      t.datetime :published_at
      t.references :author, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :entries, :slug, unique: true
  end
end
