class ConvertToPlumEngineSchema < ActiveRecord::Migration[8.0]
  RENAMED_TABLES = {
    site_settings: :plum_site_settings,
    content_types: :plum_content_types,
    entries: :plum_entries,
    globals: :plum_globals,
    nav_menus: :plum_nav_menus,
    nav_items: :plum_nav_items,
    assets: :plum_assets,
    users: :plum_users,
    form_definitions: :plum_form_definitions,
    form_submissions: :plum_form_submissions
  }.freeze

  SITE_SCOPED_TABLES = %i[
    plum_site_settings
    plum_content_types
    plum_entries
    plum_globals
    plum_nav_menus
    plum_nav_items
    plum_assets
    plum_form_definitions
    plum_form_submissions
  ].freeze

  def up
    RENAMED_TABLES.each do |old_name, new_name|
      rename_table old_name, new_name
    end

    create_table :plum_sites do |t|
      t.string :name, null: false
      t.string :domain
      t.string :theme_name
      t.json :settings
      t.timestamps
    end

    site_name = select_value("SELECT name FROM plum_site_settings LIMIT 1").presence || "My Site"
    theme_name = select_value("SELECT theme_name FROM plum_site_settings LIMIT 1").presence || "default"

    execute sanitize_sql([
      "INSERT INTO plum_sites (name, theme_name, created_at, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
      site_name,
      theme_name
    ])

    site_id = select_value("SELECT id FROM plum_sites LIMIT 1")

    SITE_SCOPED_TABLES.each do |table|
      add_reference table, :site, foreign_key: { to_table: :plum_sites }
      update "UPDATE #{table} SET site_id = #{site_id}"
      change_column_null table, :site_id, false
    end

    change_column_null :plum_entries, :author_id, true
    add_column :plum_entries, :author_name, :string
    add_column :plum_entries, :author_email, :string
    add_column :plum_entries, :author_gid, :string

    update_active_storage_record_types
    replace_global_indexes
  end

  def down
    remove_site_scoped_indexes

    remove_column :plum_entries, :author_gid
    remove_column :plum_entries, :author_email
    remove_column :plum_entries, :author_name
    change_column_null :plum_entries, :author_id, false

    SITE_SCOPED_TABLES.each do |table|
      remove_reference table, :site, foreign_key: { to_table: :plum_sites }
    end

    drop_table :plum_sites

    RENAMED_TABLES.each do |old_name, new_name|
      rename_table new_name, old_name
    end

    restore_global_indexes
  end

  private

  def replace_global_indexes
    remove_index :plum_entries, :slug
    add_index :plum_entries, [ :site_id, :slug ], unique: true

    remove_index :plum_content_types, :handle
    add_index :plum_content_types, [ :site_id, :handle ], unique: true

    remove_index :plum_globals, :handle
    add_index :plum_globals, [ :site_id, :handle ], unique: true

    remove_index :plum_nav_menus, :handle
    add_index :plum_nav_menus, [ :site_id, :handle ], unique: true

    remove_index :plum_form_definitions, :handle
    add_index :plum_form_definitions, [ :site_id, :handle ], unique: true

    remove_index :plum_site_settings, :site_id if index_exists?(:plum_site_settings, :site_id)
    add_index :plum_site_settings, :site_id, unique: true
  end

  def remove_site_scoped_indexes
    remove_index :plum_site_settings, :site_id
    remove_index :plum_form_definitions, [ :site_id, :handle ]
    remove_index :plum_nav_menus, [ :site_id, :handle ]
    remove_index :plum_globals, [ :site_id, :handle ]
    remove_index :plum_content_types, [ :site_id, :handle ]
    remove_index :plum_entries, [ :site_id, :slug ]
  end

  def restore_global_indexes
    add_index :entries, :slug, unique: true
    add_index :content_types, :handle, unique: true
    add_index :globals, :handle, unique: true
    add_index :nav_menus, :handle, unique: true
    add_index :form_definitions, :handle, unique: true
  end

  def update_active_storage_record_types
    update <<~SQL.squish
      UPDATE active_storage_attachments
      SET record_type = 'Plum::Asset'
      WHERE record_type = 'Asset'
    SQL
  end

  def sanitize_sql(values)
    ActiveRecord::Base.sanitize_sql_array(values)
  end
end
