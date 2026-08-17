require "net/http"
require "json"
require "securerandom"

module Ocr
  class TesseractOcrAdapter
    ENDPOINT = "http://localhost:8002/ocr"

    def initialize(document)
      @document = document
    end

    def call
      raise "Document file is not attached" unless @document.file.attached?

      uri = URI(ENDPOINT)
      boundary = "----RubyMultipart#{SecureRandom.hex(16)}"

      request = Net::HTTP::Post.new(uri)

      request["Content-Type"] =
        "multipart/form-data; boundary=#{boundary}"

      request.body = build_multipart_body(boundary)

      http = Net::HTTP.new(uri.host, uri.port)

      http.open_timeout = 10
      http.read_timeout = 120

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "Tesseract OCR error #{response.code}: #{response.body}"
      end

      JSON.parse(response.body)
    end

    private

    def build_multipart_body(boundary)
      filename = @document.file.filename.to_s

      content_type =
        @document.file.content_type.presence ||
        "application/octet-stream"

      file_data = @document.file.download

      body = +""

      body << "--#{boundary}\r\n"
      body << %(Content-Disposition: form-data; name="file"; filename="#{filename}"\r\n)
      body << "Content-Type: #{content_type}\r\n"
      body << "\r\n"
      body << file_data
      body << "\r\n"
      body << "--#{boundary}--\r\n"

      body
    end
  end
end