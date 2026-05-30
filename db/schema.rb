# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_30_001500) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "plum_assets", force: :cascade do |t|
    t.string "alt_text"
    t.text "caption"
    t.string "folder"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id", null: false
    t.index ["site_id"], name: "index_plum_assets_on_site_id"
  end

  create_table "plum_content_types", force: :cascade do |t|
    t.string "name"
    t.string "handle"
    t.boolean "singleton"
    t.json "blueprint"
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id", null: false
    t.index ["site_id", "handle"], name: "index_plum_content_types_on_site_id_and_handle", unique: true
    t.index ["site_id"], name: "index_plum_content_types_on_site_id"
  end

  create_table "plum_entries", force: :cascade do |t|
    t.integer "content_type_id", null: false
    t.string "title"
    t.string "slug"
    t.integer "status"
    t.json "data"
    t.datetime "published_at"
    t.integer "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id", null: false
    t.string "author_name"
    t.string "author_email"
    t.string "author_gid"
    t.index ["author_id"], name: "index_plum_entries_on_author_id"
    t.index ["content_type_id"], name: "index_plum_entries_on_content_type_id"
    t.index ["site_id", "slug"], name: "index_plum_entries_on_site_id_and_slug", unique: true
    t.index ["site_id"], name: "index_plum_entries_on_site_id"
  end

  create_table "plum_form_definitions", force: :cascade do |t|
    t.string "name"
    t.string "handle"
    t.json "fields"
    t.string "notification_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id", null: false
    t.index ["site_id", "handle"], name: "index_plum_form_definitions_on_site_id_and_handle", unique: true
    t.index ["site_id"], name: "index_plum_form_definitions_on_site_id"
  end

  create_table "plum_form_submissions", force: :cascade do |t|
    t.integer "form_definition_id", null: false
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id", null: false
    t.index ["form_definition_id"], name: "index_plum_form_submissions_on_form_definition_id"
    t.index ["site_id"], name: "index_plum_form_submissions_on_site_id"
  end

  create_table "plum_globals", force: :cascade do |t|
    t.string "name"
    t.string "handle"
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id", null: false
    t.index ["site_id", "handle"], name: "index_plum_globals_on_site_id_and_handle", unique: true
    t.index ["site_id"], name: "index_plum_globals_on_site_id"
  end

  create_table "plum_nav_items", force: :cascade do |t|
    t.integer "nav_menu_id", null: false
    t.integer "parent_id"
    t.string "label"
    t.string "url"
    t.integer "entry_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id", null: false
    t.index ["entry_id"], name: "index_plum_nav_items_on_entry_id"
    t.index ["nav_menu_id"], name: "index_plum_nav_items_on_nav_menu_id"
    t.index ["parent_id"], name: "index_plum_nav_items_on_parent_id"
    t.index ["site_id"], name: "index_plum_nav_items_on_site_id"
  end

  create_table "plum_nav_menus", force: :cascade do |t|
    t.string "name"
    t.string "handle"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "site_id", null: false
    t.index ["site_id", "handle"], name: "index_plum_nav_menus_on_site_id_and_handle", unique: true
    t.index ["site_id"], name: "index_plum_nav_menus_on_site_id"
  end

  create_table "plum_site_settings", force: :cascade do |t|
    t.string "name"
    t.string "tagline"
    t.string "logo"
    t.string "favicon"
    t.string "seo_title"
    t.string "seo_description"
    t.string "theme_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "primary_color"
    t.string "support_email"
    t.integer "site_id", null: false
    t.index ["site_id"], name: "index_plum_site_settings_on_site_id", unique: true
  end

  create_table "plum_sites", force: :cascade do |t|
    t.string "name", null: false
    t.string "domain"
    t.string "theme_name"
    t.json "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "theme_settings", default: {}, null: false
    t.text "custom_css"
    t.string "owner_type"
    t.integer "owner_id"
    t.index ["owner_type", "owner_id"], name: "index_plum_sites_on_owner"
  end

  create_table "plum_users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_plum_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "plum_assets", "plum_sites", column: "site_id"
  add_foreign_key "plum_content_types", "plum_sites", column: "site_id"
  add_foreign_key "plum_entries", "plum_content_types", column: "content_type_id"
  add_foreign_key "plum_entries", "plum_sites", column: "site_id"
  add_foreign_key "plum_entries", "plum_users", column: "author_id"
  add_foreign_key "plum_form_definitions", "plum_sites", column: "site_id"
  add_foreign_key "plum_form_submissions", "plum_form_definitions", column: "form_definition_id"
  add_foreign_key "plum_form_submissions", "plum_sites", column: "site_id"
  add_foreign_key "plum_globals", "plum_sites", column: "site_id"
  add_foreign_key "plum_nav_items", "plum_entries", column: "entry_id"
  add_foreign_key "plum_nav_items", "plum_nav_items", column: "parent_id"
  add_foreign_key "plum_nav_items", "plum_nav_menus", column: "nav_menu_id"
  add_foreign_key "plum_nav_items", "plum_sites", column: "site_id"
  add_foreign_key "plum_nav_menus", "plum_sites", column: "site_id"
  add_foreign_key "plum_site_settings", "plum_sites", column: "site_id"
end
