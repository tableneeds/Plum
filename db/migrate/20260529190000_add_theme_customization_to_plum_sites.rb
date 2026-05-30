class AddThemeCustomizationToPlumSites < ActiveRecord::Migration[8.0]
  def change
    add_column :plum_sites, :theme_settings, :json, default: {}, null: false
    add_column :plum_sites, :custom_css, :text
  end
end
