class AddUniqueOwnerIndexToPlumSites < ActiveRecord::Migration[8.0]
  def change
    remove_index :plum_sites, name: "index_plum_sites_on_owner", if_exists: true
    add_index :plum_sites, [ :owner_type, :owner_id ], unique: true, name: "index_plum_sites_on_owner"
  end
end
