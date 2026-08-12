class RenameModelNameInOcrRuns < ActiveRecord::Migration[8.1]
  def change
    rename_column :ocr_runs, :model_name, :provider_model
  end
end