module Jennifer
  module Migration
    module TableBuilder
      class CreateIndex < Base
        getter index_name : String, _fields : Array(Symbol), type : Symbol?,
          lengths : Hash(Symbol, Int32), orders : Hash(Symbol, Symbol)

        def initialize(adapter, table_name, @index_name, @_fields, @type, @lengths, @orders)
          super(adapter, table_name)
        end

        def process
          migration_processor.add_index(@name, @index_name, _fields, @type, orders, @lengths)
        end
      end
    end
  end
end
