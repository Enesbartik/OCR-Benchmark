module Ocr
  class AzureRunner
    def initialize(document)
      @document = document
    end

    def call
      ocr_run = @document.ocr_runs.create!(
        provider: "azure",
        status: "running"
      )

      adapter = Ocr::AzureAdapter.new(@document)

      operation_url = adapter.call
      result = adapter.wait_for_result(operation_url)

      extracted_text = result.dig("analyzeResult", "content")

      ocr_run.update!(
        status: "completed",
        extracted_text: extracted_text,
        raw_response: result,
        error_message: nil
      )

      ocr_run

    rescue => error
      ocr_run&.update(
        status: "failed",
        error_message: error.message
      )

      raise
    end
  end
end