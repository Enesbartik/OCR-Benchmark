module Ocr
  class ProviderRegistry
    PROVIDERS = {
      "azure_content_understanding" => {
        name: "Azure Content Understanding",
        runner: "Ocr::ContentUnderstandingRunner"
      },

      "mistral" => {
        name: "Mistral OCR",
        runner: "Ocr::MistralRunner"
      },

      "gemini" => {
        name: "Gemini",
        runner: "Ocr::GeminiRunner"
      },

      "paddle_ocr" => {
        name: "PaddleOCR",
        runner: "Ocr::PaddleOcrRunner"
      }
    }.freeze

    def self.all
      PROVIDERS
    end

    def self.keys
      PROVIDERS.keys
    end

    def self.exists?(provider)
      PROVIDERS.key?(provider)
    end

    def self.runner_for(provider)
      config = PROVIDERS.fetch(provider) do
        raise ArgumentError, "Bilinmeyen OCR provider: #{provider}"
      end

      config.fetch(:runner).constantize
    end
  end
end