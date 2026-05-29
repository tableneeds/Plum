class CreateSiteSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :site_settings do |t|
      t.string :name
      t.string :tagline
      t.string :logo
      t.string :favicon
      t.string :meta_title
      t.string :meta_description
      t.string :theme_name

      t.timestamps
    end
  end
end
