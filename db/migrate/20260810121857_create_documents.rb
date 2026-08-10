class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :name
      t.string :document_type
      t.text :notes

      t.timestamps
    end
  end
end
