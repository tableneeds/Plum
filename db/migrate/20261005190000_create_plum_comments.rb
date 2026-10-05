class CreatePlumComments < ActiveRecord::Migration[8.0]
  def change
    add_column :plum_content_types, :comments_enabled, :boolean, default: false, null: false
    add_column :plum_entries, :comments_mode, :string, default: "inherit", null: false

    create_table :plum_discussions do |t|
      t.references :site, null: false, foreign_key: { to_table: :plum_sites }
      t.string :commentable_type, null: false
      t.string :commentable_id, null: false
      t.string :subject_handle, null: false
      t.boolean :closed, null: false, default: false
      t.timestamps
    end
    add_index :plum_discussions, [ :site_id, :commentable_type, :commentable_id ], unique: true, name: "plum_discussion_subject_unique"

    create_table :plum_comments do |t|
      t.references :discussion, null: false, foreign_key: { to_table: :plum_discussions }
      t.references :parent, foreign_key: { to_table: :plum_comments }
      t.string :author_gid, null: false
      t.string :author_name, null: false
      t.string :author_badge
      t.text :body, null: false
      t.string :status, null: false, default: "pending"
      t.boolean :pinned, null: false, default: false
      t.integer :video_seconds
      t.timestamps
    end
    add_index :plum_comments, [ :discussion_id, :status, :id ]
    add_index :plum_comments, [ :author_gid, :created_at ]

    create_table :plum_comment_reports do |t|
      t.references :comment, null: false, foreign_key: { to_table: :plum_comments }
      t.string :reporter_gid, null: false
      t.text :reason, null: false
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :plum_comment_reports, [ :comment_id, :reporter_gid ], unique: true

    create_table :plum_comment_moderations do |t|
      t.references :comment, null: false, foreign_key: { to_table: :plum_comments }
      t.string :moderator_gid, null: false
      t.string :action, null: false
      t.string :previous_status, null: false
      t.timestamps
    end
  end
end
