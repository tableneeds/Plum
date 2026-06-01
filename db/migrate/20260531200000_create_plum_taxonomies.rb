class CreatePlumTaxonomies < ActiveRecord::Migration[8.0]
  def change
    create_table :plum_taxonomies do |t|
      t.references :site, null: false, foreign_key: { to_table: :plum_sites }
      t.string :name, null: false
      t.string :handle, null: false
      t.string :slug, null: false
      t.timestamps
    end

    add_index :plum_taxonomies, [ :site_id, :handle ], unique: true
    add_index :plum_taxonomies, [ :site_id, :slug ], unique: true

    create_table :plum_terms do |t|
      t.references :site, null: false, foreign_key: { to_table: :plum_sites }
      t.references :taxonomy, null: false, foreign_key: { to_table: :plum_taxonomies }
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :plum_terms, [ :taxonomy_id, :slug ], unique: true

    create_table :plum_entry_terms do |t|
      t.references :entry, null: false, foreign_key: { to_table: :plum_entries }
      t.references :term, null: false, foreign_key: { to_table: :plum_terms }
    end

    add_index :plum_entry_terms, [ :entry_id, :term_id ], unique: true
  end
end
