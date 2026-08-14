module Ocr
  class PaddleOcrRunner
    def initialize(document)
      @document = document
    end

    def call
      response =
        Ocr::PaddleOcrAdapter
          .new(@document)
          .call

      {
        raw_response: {
          provider: response["provider"],
          model: response["model"],
          filename: response["filename"],
          duration_ms: response["duration_ms"],
          pages: response["pages"]
        },

        extracted_text:
          response["text"],

        normalized_output:
        {},

        page_count:
          response["pages"]&.length,

        input_tokens:
          nil,

        output_tokens:
          nil,

        provider_model:
          response["model"] || "PP-OCRv6-medium",

        prompt_version:
          nil
      }
    end
  end
end