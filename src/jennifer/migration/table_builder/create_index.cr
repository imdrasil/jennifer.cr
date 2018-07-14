module Jennifer
  module Migration
    module TableBuilder
      class CreateIndex < Base
        getter index_name : String, fields : Array(Symbol), type : Symbol?,
          lengths : Hash(Symbol, Int32), orders : Hash(Symbol, Symbol)

        def initialize(adapter, table_name, @index_name, @fields, @type, @lengths, @orders)
          super(adapter, table_name)
        end

        def process
          schema_processor.add_index(@name, @index_name, fields, @type, orders, @lengths)
        end
      end
    end
  end
end
