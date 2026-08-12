require "net/http"
require "json"

module Ocr
  class ContentUnderstandingAnalyzerSetup
    API_VERSION = "2025-11-01"
    ANALYZER_ID = "customsDeclarationV1"

    def initialize
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
        "contentunderstanding/analyzers/#{ANALYZER_ID}"
      )

        uri.query = URI.encode_www_form(
        "api-version" => API_VERSION,
        "allowReplace" => "true"
        )       
      request = Net::HTTP::Put.new(uri)

      request["Ocp-Apim-Subscription-Key"] = @key
      request["Content-Type"] = "application/json"

      request.body = File.read(schema_path)

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https"
      ) do |http|
        http.request(request)
      end

      unless ["201", "202"].include?(response.code)
        raise "Analyzer creation failed: #{response.code} #{response.body}"
      end

      operation_url = response["Operation-Location"]

      raise "Operation-Location dönmedi" if operation_url.blank?

      operation_url
    end

    def fetch_status(operation_url)
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
        raise "Analyzer status request failed: #{response.code} #{response.body}"
      end

      JSON.parse(response.body)
    end

    def wait_until_ready(operation_url)
      loop do
        result = fetch_status(operation_url)

        case result["status"]&.downcase
        when "succeeded"
          return result
        when "failed"
          raise "Analyzer creation failed: #{result}"
        else
          sleep 1
        end
      end
    end

    private

    def schema_path
      Rails.root.join(
        "config",
        "ocr",
        "beyanname_analyzer.json"
      )
    end

    def validate!
      raise "Content Understanding endpoint eksik" if @endpoint.blank?
      raise "Content Understanding key eksik" if @key.blank?
      raise "Analyzer JSON bulunamadı: #{schema_path}" unless File.exist?(schema_path)

      JSON.parse(File.read(schema_path))
    rescue JSON::ParserError => error
      raise "Analyzer JSON geçersiz: #{error.message}"
    end
  end
end