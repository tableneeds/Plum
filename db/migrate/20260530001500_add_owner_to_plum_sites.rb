class AddOwnerToPlumSites < ActiveRecord::Migration[8.0]
  def change
    add_reference :plum_sites, :owner, polymorphic: true, index: true
  end
end
