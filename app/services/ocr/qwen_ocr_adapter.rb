require "net/http"
require "json"
require "base64"

module Ocr
  class QwenOcrAdapter
    MODEL = "qwen-vl-ocr-2025-11-20"

    def initialize(document)
      @document = document

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
        URI(
          "#{@base_url}/chat/completions"
        )

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
              role: "user",

              content: [
                image_payload,

                {
                  type: "text",
                  text: prompt
                }
              ]
            }
          ]
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
          "Qwen OCR error #{response.code}: #{response.body}"
        )
      end

      JSON.parse(response.body)
    end

    private

    def image_payload
      file =
        @document.file.blob.download

      mime_type =
        @document.file.blob.content_type

      unless [
        "image/png",
        "image/jpeg"
      ].include?(mime_type)
        raise(
          "Qwen OCR ilk testte sadece PNG/JPEG destekleniyor. " \
          "Gelen dosya: #{mime_type}"
        )
      end

      encoded =
        Base64.strict_encode64(file)

      {
        type: "image_url",

        image_url: {
          url:
            "data:#{mime_type};base64,#{encoded}"
        }
      }
    end

    def prompt
      "qwenvl html"
    end
    
  end
end