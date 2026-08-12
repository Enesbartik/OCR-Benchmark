require "json"

module Ocr
  class MistralSchemaBuilder
    SCHEMA_PATH =
      Rails.root.join(
        "config",
        "ocr",
        "beyanname_analyzer.json"
      )

    def self.call
      azure_schema =
        JSON.parse(
          File.read(SCHEMA_PATH)
        )

      fields =
        azure_schema.dig(
          "fieldSchema",
          "fields"
        )

      {
        "type" => "object",
        "properties" =>
          fields.transform_values do |field|
            convert_field(field)
          end,
        "additionalProperties" => false
      }
    end

    def self.convert_field(field)
      result = {}

      if field["description"].present?
        result["description"] =
          field["description"]
      end

      case field["type"]
      when "string"
        result["type"] = "string"

      when "date"
        result["type"] = "string"

      when "number"
        result["type"] = "number"

      when "boolean"
        result["type"] = "boolean"

      when "object"
        result["type"] = "object"

        result["properties"] =
          field
            .fetch("properties", {})
            .transform_values do |child|
              convert_field(child)
            end

        result["additionalProperties"] = false

      when "array"
        result["type"] = "array"

        result["items"] =
          convert_field(
            field.fetch("items")
          )

      else
        raise "Bilinmeyen schema tipi: #{field['type']}"
      end

      result
    end

    private_class_method :convert_field
  end
end