module Ocr
  class AzureFieldNormalizer
    def self.call(fields)
      return {} unless fields.is_a?(Hash)

      fields.transform_values do |field|
        normalize_field(field)
      end
    end

    def self.normalize_field(field)
      return nil unless field.is_a?(Hash)

      case field["type"]
      when "string"
        field["valueString"]

      when "number"
        field["valueNumber"]

      when "date"
        field["valueDate"]

      when "boolean"
        field["valueBoolean"]

      when "object"
        normalize_object(field["valueObject"])

      when "array"
        normalize_array(field["valueArray"])

      else
        nil
      end
    end

    def self.normalize_object(value_object)
      return {} unless value_object.is_a?(Hash)

      value_object.transform_values do |field|
        normalize_field(field)
      end
    end

    def self.normalize_array(value_array)
      return [] unless value_array.is_a?(Array)

      value_array.map do |item|
        normalize_field(item)
      end
    end

    private_class_method :normalize_field,
                         :normalize_object,
                         :normalize_array
  end
end