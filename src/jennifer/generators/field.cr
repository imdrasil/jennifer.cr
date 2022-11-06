module Jennifer
  module Generators
    class Field
      REFERENCE_TYPE = "reference"

      DATA_TYPES = {
        "bool" => "Bool",

        "bigint"  => "Int64",
        "integer" => "Int32",
        "short"   => "Int16",
        "tinyint" => "Int8",

        "float"  => "Float32",
        "double" => "Double64",

        "decimal" => "Float64", # PG::Numeric

        "string" => "String",
        "text"   => "String",

        "timestamp" => "Time",
        "date_time" => "Time",

        "json"  => "JSON::Any",
        "jsonb" => "JSON::Any",

        REFERENCE_TYPE => "Int64",
      }

      getter name : String, type : String, nilable : Bool

      def initialize(@name, @type, @nilable)
        unless DATA_TYPES.has_key?(@type)
          raise "Invalid type `#{@type}`. Only following data types are allowed: #{DATA_TYPES.keys.join(", ")}"
        end
        @nilable = true if @type == REFERENCE_TYPE
      end

      def ==(other)
        name == other.name && type == other.type && nilable == other.nilable
      end

      def field_name
        reference? ? Wordsmith::Inflector.foreign_key(name) : name
      end

      def cr_type
        definition =
          if id?
            primary_type
          else
            DATA_TYPES[type]
          end
        definition += "?" if nilable && !id?
        definition
      end

      def reference_class
        name.camelcase
      end

      def id?
        name == "id"
      end

      def decimal?
        type == "decimal"
      end

      def reference?
        type == REFERENCE_TYPE
      end

      def timestamp?
        name == "created_at" || name == "updated_at"
      end

      private def primary_type
        if type == "bigint"
          "Primary64"
        elsif type == "integer"
          "Primary32"
        else
          DATA_TYPES[type]
        end
      end
    end
  end
end
