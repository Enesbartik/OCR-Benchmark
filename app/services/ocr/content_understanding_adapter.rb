require "net/http"
require "json"

module Ocr
  class ContentUnderstandingAdapter
    API_VERSION = "2025-11-01"
    ANALYZER_ID = "customsDeclarationV1"

    def initialize(document)
      @document = document

      @endpoint =
        Rails.application.credentials.dig(
          :azure_content_understanding,
          :endpoint
        )

      @key =
        Rails.application.credentials.dig(
          :azure_content_understanding,
          :key
        )
    end

    def call
      validate!

      uri = URI.join(
        @endpoint,
        "contentunderstanding/analyzers/#{ANALYZER_ID}:analyzeBinary"
      )

      uri.query = URI.encode_www_form(
        "api-version" => API_VERSION
      )

      request = Net::HTTP::Post.new(uri)

      request["Ocp-Apim-Subscription-Key"] = @key
      request["Content-Type"] =
        @document.file.content_type || "application/octet-stream"

      request.body = @document.file.download

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https"
      ) do |http|
        http.request(request)
      end

      unless response.code == "202"
        raise "Content Understanding request failed: #{response.code} #{response.body}"
      end

      response["Operation-Location"]
    end

    def fetch_result(operation_url)
      uri = URI(operation_url)

      request = Net::HTTP::Get.new(uri)
      request["Ocp-Apim-Subscription-Key"] = @key

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https"
      ) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise "Content Understanding result request failed: #{response.code} #{response.body}"
      end

      JSON.parse(response.body)
    end

    def wait_for_result(operation_url)
      loop do
        result = fetch_result(operation_url)

        case result["status"]&.downcase
        when "succeeded"
          return result
        when "failed"
          raise "Content Understanding analysis failed: #{result}"
        else
          sleep 1
        end
      end
    end

    private

    def validate!
      raise "Content Understanding endpoint eksik" if @endpoint.blank?
      raise "Content Understanding key eksik" if @key.blank?
      raise "Document dosyası yok" unless @document.file.attached?
    end
  end
end