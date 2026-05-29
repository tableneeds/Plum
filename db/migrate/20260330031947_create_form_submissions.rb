class CreateFormSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :form_submissions do |t|
      t.references :form_definition, null: false, foreign_key: true
      t.json :data

      t.timestamps
    end
  end
end
