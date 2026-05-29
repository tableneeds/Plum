class CreateAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :assets do |t|
      t.string :alt_text
      t.text :caption
      t.string :folder

      t.timestamps
    end
  end
end
