require "net/http"
require "json"
require "base64"

module Ocr
  class GlmVisionAdapter
    MODEL = "glm-4.6v-flash"

    ENDPOINT =
      URI(
        "https://api.z.ai/api/paas/v4/chat/completions"
      )

    def initialize(document)
      @document = document

      @api_key =
        Rails.application.credentials.dig(
          :zai,
          :api_key
        )

      raise "Z.AI API key eksik" if @api_key.blank?
    end

    def call
      request =
        Net::HTTP::Post.new(ENDPOINT)

      request["Authorization"] =
        "Bearer #{@api_key}"

      request["Content-Type"] =
        "application/json"

      request.body =
        {
          model: MODEL,

          messages: [
            {
              role: "user",

              content: [
                image_part,

                {
                  type: "text",
                  text: prompt
                }
              ]
            }
          ],

          thinking: {
            type: "disabled"
          },

          response_format: {
            type: "json_object"
          },

          do_sample: false,

          max_tokens: 8_000
        }.to_json

      response =
        Net::HTTP.start(
          ENDPOINT.hostname,
          ENDPOINT.port,
          use_ssl: true,
          open_timeout: 10,
          read_timeout: 180
        ) do |http|
          http.request(request)
        end

      unless response.is_a?(Net::HTTPSuccess)
        raise(
          "GLM Vision error #{response.code}: " \
          "#{response.body}"
        )
      end

      JSON.parse(response.body)
    end

    private

    def image_part
      blob =
        @document.file.blob

      unless blob.content_type.start_with?("image/")
        raise(
          "İlk GLM Vision testi için image gerekli. " \
          "Gelen: #{blob.content_type}"
        )
      end

      encoded =
        Base64.strict_encode64(
          blob.download
        )

      {
        type: "image_url",

        image_url: {
          url:
            "data:#{blob.content_type};base64,#{encoded}"
        }
      }
    end

    def prompt
      schema =
        Ocr::MistralSchemaBuilder.call

      <<~PROMPT
        Extract structured information from this customs declaration.

        Return ONLY one valid JSON object.

        The JSON object must follow the provided canonical schema exactly.
        Do not add extra top-level fields.

        Rules:

        - Extract only values supported by the document.
        - If a value cannot be reliably identified, return null.
        - Never invent missing information.
        - Never replace an unknown value with 0 or an empty string.
        - Do not copy values into unrelated fields.
        - Tax identifiers are not declaration numbers.
        - Package counts are not automatically goods quantities.
        - Commodity / GTIP codes are not automatically CPC codes.
        - Weight values are not monetary values.
        - Preserve all visible GTIP / HS code digits.
        - Preserve values belonging to the same goods item together.
        - Country fields should use two-letter country codes when identifiable.

        Canonical JSON Schema:

        #{JSON.pretty_generate(schema)}
      PROMPT
    end
  end
end