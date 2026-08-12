require "json"

module Ocr
  class MistralRunner
    MODEL_NAME = "mistral-ocr-4-0"

    def initialize(document)
      @document = document
    end

    def call
      adapter = Ocr::MistralAdapter.new(@document)

      result = adapter.call

      normalized_output =
        parse_document_annotation(
          result["document_annotation"]
        )

      extracted_text =
        Array(result["pages"])
          .filter_map { |page| page["markdown"] }
          .join("\n\n")

      {
        raw_response: result,

        extracted_text:
          extracted_text,

        normalized_output:
          normalized_output,

        page_count:
          result.dig("usage_info", "pages_processed"),

        input_tokens:
          nil,

        output_tokens:
          nil,

        provider_model:
          result["model"].presence || MODEL_NAME
      }
    end

    private

    def parse_document_annotation(annotation)
      return {} if annotation.blank?

      case annotation
      when String
        JSON.parse(annotation)
      when Hash
        annotation
      else
        {}
      end
    rescue JSON::ParserError => error
      raise "Mistral document_annotation JSON parse edilemedi: #{error.message}"
    end
  end
end