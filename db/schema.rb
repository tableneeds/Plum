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

ActiveRecord::Schema[8.0].define(version: 2026_05_29_144500) do
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

  create_table "assets", force: :cascade do |t|
    t.string "alt_text"
    t.text "caption"
    t.string "folder"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "content_types", force: :cascade do |t|
    t.string "name"
    t.string "handle"
    t.boolean "singleton"
    t.json "blueprint"
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["handle"], name: "index_content_types_on_handle", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.integer "content_type_id", null: false
    t.string "title"
    t.string "slug"
    t.integer "status"
    t.json "data"
    t.datetime "published_at"
    t.integer "author_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_entries_on_author_id"
    t.index ["content_type_id"], name: "index_entries_on_content_type_id"
    t.index ["slug"], name: "index_entries_on_slug", unique: true
  end

  create_table "form_definitions", force: :cascade do |t|
    t.string "name"
    t.string "handle"
    t.json "fields"
    t.string "notification_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["handle"], name: "index_form_definitions_on_handle", unique: true
  end

  create_table "form_submissions", force: :cascade do |t|
    t.integer "form_definition_id", null: false
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["form_definition_id"], name: "index_form_submissions_on_form_definition_id"
  end

  create_table "globals", force: :cascade do |t|
    t.string "name"
    t.string "handle"
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["handle"], name: "index_globals_on_handle", unique: true
  end

  create_table "nav_items", force: :cascade do |t|
    t.integer "nav_menu_id", null: false
    t.integer "parent_id"
    t.string "label"
    t.string "url"
    t.integer "entry_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_nav_items_on_entry_id"
    t.index ["nav_menu_id"], name: "index_nav_items_on_nav_menu_id"
    t.index ["parent_id"], name: "index_nav_items_on_parent_id"
  end

  create_table "nav_menus", force: :cascade do |t|
    t.string "name"
    t.string "handle"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["handle"], name: "index_nav_menus_on_handle", unique: true
  end

  create_table "site_settings", force: :cascade do |t|
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
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "entries", "content_types"
  add_foreign_key "entries", "users", column: "author_id"
  add_foreign_key "form_submissions", "form_definitions"
  add_foreign_key "nav_items", "entries"
  add_foreign_key "nav_items", "nav_items", column: "parent_id"
  add_foreign_key "nav_items", "nav_menus"
end
