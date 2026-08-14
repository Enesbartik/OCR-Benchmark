require "json"

module Ocr
  class GlmVisionRunner
    PROMPT_VERSION = "glm_vision_customs_v1"

    def initialize(document)
      @document = document
    end

    def call
      raw_response =
        Ocr::GlmVisionAdapter
          .new(@document)
          .call

      extracted_text =
        raw_response.dig(
          "choices",
          0,
          "message",
          "content"
        )

      if extracted_text.blank?
        raise "GLM Vision structured output boş döndü"
      end

      normalized_output =
        JSON.parse(extracted_text)

      usage =
        raw_response["usage"] || {}

      {
        raw_response: raw_response,
        extracted_text: extracted_text,
        normalized_output: normalized_output,

        page_count: page_count,

        input_tokens:
          usage["prompt_tokens"],

        output_tokens:
          usage["completion_tokens"],

        provider_model:
          raw_response["model"],

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