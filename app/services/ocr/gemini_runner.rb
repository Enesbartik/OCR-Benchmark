module Ocr
  class GeminiRunner
    PROMPT_VERSION = "gemini_customs_v1"

    def initialize(document)
      @document = document
    end

    def call
      raw_response =
        Ocr::GeminiAdapter
          .new(@document)
          .call

      extracted_text =
        raw_response.dig(
          "candidates",
          0,
          "content",
          "parts",
          0,
          "text"
        )

      if extracted_text.blank?
        raise "Gemini structured output boş döndü"
      end

      normalized_output =
        JSON.parse(extracted_text)

      usage =
        raw_response["usageMetadata"] || {}

      {
        raw_response: raw_response,

        extracted_text: extracted_text,

        normalized_output: normalized_output,

        page_count: page_count,

        input_tokens:
          usage["promptTokenCount"],

        output_tokens:
          usage["candidatesTokenCount"],

        provider_model:
          raw_response["modelVersion"],

        prompt_version:
          PROMPT_VERSION
      }
    end

    private

    def page_count
      content_type =
        @document.file.blob.content_type

      return 1 if content_type.start_with?("image/")

      nil
    end
  end
end