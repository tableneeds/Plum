class AlignSiteSettingsWithBrief < ActiveRecord::Migration[8.0]
  def change
    rename_column :site_settings, :meta_title, :seo_title
    rename_column :site_settings, :meta_description, :seo_description

    add_column :site_settings, :primary_color, :string
    add_column :site_settings, :support_email, :string
  end
end
