class AddBenchmarkFieldsToOcrRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :ocr_runs, :normalized_output, :jsonb,
               default: {},
               null: false

    add_column :ocr_runs, :started_at, :datetime
    add_column :ocr_runs, :finished_at, :datetime
    add_column :ocr_runs, :duration_ms, :integer

    add_column :ocr_runs, :page_count, :integer
    add_column :ocr_runs, :input_tokens, :integer
    add_column :ocr_runs, :output_tokens, :integer

    add_column :ocr_runs, :cost_usd, :decimal,
               precision: 12,
               scale: 6

    add_column :ocr_runs, :note, :text
    add_column :ocr_runs, :model_name, :string
    add_column :ocr_runs, :prompt_version, :string

    add_index :ocr_runs,
              [:provider, :status, :created_at],
              name: "index_ocr_runs_for_inspection"
  end
end