require "./create_index"

module Jennifer
  module Migration
    module TableBuilder
      class DropIndex < Base
        @index_name : String
        @fields : Array(Symbol)

        def initialize(adapter, name, fields, index_name : String?)
          raise ArgumentError.new if fields.empty? && (index_name.nil? || index_name.empty?)
          super(adapter, name)
          @fields = fields
          @index_name = CreateIndex.generate_index_name(name, fields, index_name)
        end

        def process
          schema_processor.drop_index(@name, @index_name)
        end

        def explain
          fields = [@name, @fields, @name].map(&.inspect).join(", ")
          "drop_index #{fields}"
        end
      end
    end
  end
end
