module Ocr
  class GeminiSchemaBuilder
    def self.call
      convert(
        Ocr::MistralSchemaBuilder.call
      )
    end

    def self.convert(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, child), result|
          next if key == "additionalProperties"

          result[key] =
            if key == "type"
              child.to_s.upcase
            else
              convert(child)
            end
        end

      when Array
        value.map { |item| convert(item) }

      else
        value
      end
    end

    private_class_method :convert
  end
end