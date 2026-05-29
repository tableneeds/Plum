class CreateFormDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :form_definitions do |t|
      t.string :name
      t.string :handle
      t.json :fields
      t.string :notification_email

      t.timestamps
    end
    add_index :form_definitions, :handle, unique: true
  end
end
