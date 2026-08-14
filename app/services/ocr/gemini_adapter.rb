require "net/http"
require "json"
require "base64"

module Ocr
  class GeminiAdapter
    MODEL = "gemini-3.6-flash"

    def initialize(document)
      @document = document

      @api_key =
        Rails.application.credentials.dig(
          :gemini,
          :api_key
        )

      raise "Gemini API key eksik" if @api_key.blank?
    end

    def call
      uri =
        URI(
          "https://generativelanguage.googleapis.com/" \
          "v1beta/models/#{MODEL}:generateContent"
        )

      request =
        Net::HTTP::Post.new(uri)

      request["x-goog-api-key"] =
        @api_key

      request["Content-Type"] =
        "application/json"

      request.body =
        {
          contents: [
            {
              role: "user",

              parts: [
                file_part,

                {
                  text: prompt
                }
              ]
            }
          ],

          generationConfig: {
            responseMimeType: "application/json",

            responseSchema:
              Ocr::GeminiSchemaBuilder.call,

            temperature: 0.1
          }
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
          "Gemini error #{response.code}: " \
          "#{response.body}"
        )
      end

      JSON.parse(response.body)
    end

    private

    def file_part
      blob =
        @document.file.blob

      data =
        Base64.strict_encode64(
          blob.download
        )

      {
        inline_data: {
          mime_type:
            blob.content_type,

          data:
            data
        }
      }
    end

    def prompt
      <<~PROMPT
        Extract structured information from this customs declaration.

        Follow the provided JSON schema exactly.

        Rules:

        - Extract only values supported by the document.
        - If a value cannot be reliably identified, return null.
        - Never invent missing information.
        - Do not copy a value into an unrelated field.
        - Preserve relationships between labels and nearby values.
        - Preserve each goods item's values together.
        - Tax identifiers must not be used as declaration numbers.
        - Values associated with KG, gross weight or net weight are weights,
          not monetary values.
        - Preserve every visible GTIP / HS code digit.
        - Country fields should use two-letter country codes when identifiable.
      PROMPT
    end
  end
end