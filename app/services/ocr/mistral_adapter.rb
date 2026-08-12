require "net/http"
require "json"
require "base64"

module Ocr
  class MistralAdapter
    ENDPOINT = "https://api.mistral.ai/v1/ocr"
    MODEL = "mistral-ocr-4-0"

    def initialize(document)
      @document = document

      @api_key =
        Rails.application.credentials.dig(
          :mistral,
          :api_key
        )
    end

    def call
      validate!

      uri = URI(ENDPOINT)

      request = Net::HTTP::Post.new(uri)

      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"

      request.body = {
        model: MODEL,

        document: document_payload,

        document_annotation_format: {
          type: "json_schema",

          json_schema: {
            name: "CustomsDeclarationFields",
            schema: Ocr::MistralSchemaBuilder.call
          }
        },

        document_annotation_prompt:
          "Extract only values supported by the document. Do not invent missing values.",

        include_image_base64: false
      }.to_json

      http = Net::HTTP.new(uri.host, uri.port)

      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 180

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise(
          "Mistral OCR request failed: " \
          "#{response.code} #{response.body}"
        )
      end

      JSON.parse(response.body)
    end

    private

    def document_payload
      content_type =
        @document.file.content_type.presence ||
        "application/octet-stream"

      encoded =
        Base64.strict_encode64(
          @document.file.download
        )

      case content_type
      when "application/pdf"
        {
          type: "document_url",
          document_url:
            "data:application/pdf;base64,#{encoded}"
        }

      when "image/png", "image/jpeg"
        {
          type: "image_url",
          image_url:
            "data:#{content_type};base64,#{encoded}"
        }

      else
        raise(
          "Mistral tarafından desteklenmeyen dosya türü: " \
          "#{content_type}"
        )
      end
    end

    def validate!
      raise "Mistral API key eksik" if @api_key.blank?

      unless @document.file.attached?
        raise "Document dosyası yok"
      end
    end
  end
end