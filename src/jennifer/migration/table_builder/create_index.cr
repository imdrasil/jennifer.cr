module Jennifer
  module Migration
    module TableBuilder
      class CreateIndex < Base
        getter index_name : String, _fields : Array(Symbol), type : Symbol?,
          lengths : Hash(Symbol, Int32), orders : Hash(Symbol, Symbol)

        def initialize(table_name, @index_name, @_fields, @type, @lengths, @orders)
          super(table_name)
        end

        def process
          Adapter.adapter.add_index(@name, @index_name, _fields, @type, orders, @lengths)
        end
      end
    end
  end
end
