require "./field"

module Jennifer
  module Generators
    class FieldSet
      getter fields : Array(Field), id : Field

      def initialize(args : Array)
        @fields = [] of Field
        args.each do |definition|
          @fields << Field.new(*parse_field_definition(definition))
        end
        @id = @fields.find(&.id?) || Field.new("id", "bigint", true)
      end

      def references
        fields.select(&.reference?)
      end

      def common_fields
        fields.select { |field| !field.id? && !field.reference? && !field.timestamp? }
      end

      def timestamps
        [Field.new("created_at", "timestamp", true), Field.new("updated_at", "timestamp", true)]
      end

      private def parse_field_definition(string)
        parts = string.as(String).split(":")
        type = parts[1]
        nilable = false
        if type.ends_with?("?")
          type = type[0...-1]
          nilable = true
        end
        {parts[0], type, nilable}
      end
    end
  end
end
