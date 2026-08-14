require "net/http"
require "json"
require "base64"

module Ocr
  class GlmOcrAdapter
    MODEL = "glm-ocr"

    ENDPOINT =
      URI(
        "https://api.z.ai/api/paas/v4/layout_parsing"
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
          file: file_data,
          return_crop_images: false,
          need_layout_visualization: false
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
          "GLM OCR error #{response.code}: " \
          "#{response.body}"
        )
      end

      JSON.parse(response.body)
    end

    private

    def file_data
      blob =
        @document.file.blob

      supported_types = [
        "application/pdf",
        "image/jpeg",
        "image/png"
      ]

      unless supported_types.include?(blob.content_type)
        raise(
          "GLM OCR desteklenmeyen dosya tipi: " \
          "#{blob.content_type}"
        )
      end

      encoded =
        Base64.strict_encode64(
          blob.download
        )

      "data:#{blob.content_type};base64,#{encoded}"
    end
  end
end