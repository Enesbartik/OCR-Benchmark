module Ocr
  class ContentUnderstandingRunner
    MODEL_NAME = "customsDeclarationV1"

    def initialize(document)
      @document = document
    end

    def call
      adapter = Ocr::ContentUnderstandingAdapter.new(@document)

      operation_url = adapter.call
      result = adapter.wait_for_result(operation_url)

      content =
        result
          .dig("result", "contents")
          &.first

      fields = content&.dig("fields") || {}

      normalized_output =
        Ocr::AzureFieldNormalizer.call(fields)

      usage = result["usage"] || {}
      tokens = usage["tokens"] || {}

      input_tokens =
        tokens.sum do |name, count|
          name.end_with?("-input") ? count.to_i : 0
        end

      output_tokens =
        tokens.sum do |name, count|
          name.end_with?("-output") ? count.to_i : 0
        end

      {
        raw_response: result,

        extracted_text:
          content&.dig("markdown"),

        normalized_output:
          normalized_output,

        page_count:
          usage["documentPagesStandard"],

        input_tokens:
          input_tokens,

        output_tokens:
          output_tokens,

        provider_model:
          MODEL_NAME
      }
    end
  end
end