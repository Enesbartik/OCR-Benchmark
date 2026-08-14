require "net/http"
require "json"

module Ocr
  class QwenStructuredExtractor
    MODEL = "qwen3.6-flash"

    def initialize(ocr_text)
      @ocr_text = ocr_text

      @api_key =
        Rails.application.credentials.dig(
          :alibaba,
          :api_key
        )

      @base_url =
        Rails.application.credentials.dig(
          :alibaba,
          :base_url
        )

      raise "Alibaba API key eksik" if @api_key.blank?
      raise "Alibaba base URL eksik" if @base_url.blank?
    end

    def call
      uri =
        URI("#{@base_url}/chat/completions")

      request =
        Net::HTTP::Post.new(uri)

      request["Authorization"] =
        "Bearer #{@api_key}"

      request["Content-Type"] =
        "application/json"

      request.body =
        {
          model: MODEL,

          messages: [
            {
              role: "system",
              content: system_prompt
            },
            {
              role: "user",
              content: @ocr_text
            }
          ],

          response_format: {
            type: "json_object"
          },

          enable_thinking: false
        }.to_json

      response =
        Net::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: true,
          open_timeout: 10,
          read_timeout: 180
        ) do |http|
          http.request(request)
        end

      unless response.is_a?(Net::HTTPSuccess)
        raise(
          "Qwen structured extraction error " \
          "#{response.code}: #{response.body}"
        )
      end

      result =
        JSON.parse(response.body)

      content =
        result.dig(
          "choices",
          0,
          "message",
          "content"
        )

      {
        raw_response: result,
        normalized_output: JSON.parse(content),
        input_tokens: result.dig("usage", "prompt_tokens"),
        output_tokens: result.dig("usage", "completion_tokens"),
        provider_model: result["model"]
      }
    end

    private

    def system_prompt
  schema =
    Ocr::MistralSchemaBuilder.call

  <<~PROMPT
    Return the output strictly as valid JSON.

    You are a customs declaration structured-data extraction engine.

    You will receive OCR output produced from a customs declaration.

    Extract the information and return JSON only.

    The returned JSON must follow this schema exactly:

    #{JSON.pretty_generate(schema)}

    Rules:

    - Include every field defined by the JSON schema.
    - Do not create additional fields.
    - If a value cannot be reliably identified, use null.
    - Never invent missing information.
    - Do not copy a value into an unrelated field.
    - Preserve relationships between labels and nearby values.
    - Preserve goods-item relationships.
    - Tax identifiers must not be used as declaration numbers.
    - Values associated with KG, gross weight or net weight are weights,
      not monetary values.
    - GTIP / HS codes must preserve every visible digit.
    - Return valid JSON only.
    - Do not return Markdown.
    - Do not return HTML.
    - Do not use code fences.
  PROMPT
end
  end
end