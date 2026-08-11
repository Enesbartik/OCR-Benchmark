class CreateOcrRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :ocr_runs do |t|
      t.references :document, null: false, foreign_key: true
      t.string :provider
      t.string :status
      t.text :extracted_text
      t.jsonb :raw_response
      t.text :error_message

      t.timestamps
    end
  end
end
