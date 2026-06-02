class CreatePlumTaxonomies < ActiveRecord::Migration[8.0]
  def change
    create_table :plum_taxonomies do |t|
      t.references :site, null: false, foreign_key: { to_table: :plum_sites }
      t.string :name, null: false
      t.string :handle, null: false
      t.string :slug, null: false
      t.timestamps

      t.index [ :site_id, :handle ], unique: true
      t.index [ :site_id, :slug ], unique: true
    end

    create_table :plum_terms do |t|
      t.references :site, null: false, foreign_key: { to_table: :plum_sites }
      t.references :taxonomy, null: false, foreign_key: { to_table: :plum_taxonomies }
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :position, default: 0
      t.timestamps

      t.index [ :taxonomy_id, :slug ], unique: true
    end

    create_table :plum_entry_terms do |t|
      t.references :entry, null: false, foreign_key: { to_table: :plum_entries }
      t.references :term, null: false, foreign_key: { to_table: :plum_terms }

      t.index [ :entry_id, :term_id ], unique: true
    end
  end
end
