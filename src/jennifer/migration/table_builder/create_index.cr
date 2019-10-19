module Jennifer
  module Migration
    module TableBuilder
      class CreateIndex < Base
        getter index_name : String, fields : Array(Symbol), type : Symbol?,
          lengths : Hash(Symbol, Int32), orders : Hash(Symbol, Symbol)

        def initialize(adapter, table_name : String, index_name, @fields : Array, @type : Symbol?, @lengths, @orders)
          @index_name = CreateIndex.generate_index_name(table_name, @fields, index_name)
          super(adapter, table_name)
        end

        def process
          schema_processor.add_index(name, index_name, fields, type, orders, lengths)
        end

        def explain
          String.build do |io|
            io << "add_index :" <<
              name <<
              ", " <<
              fields.inspect <<
              ", " <<
              type.inspect <<
              ", " <<
              index_name.inspect <<
              ", " <<
              lengths.inspect <<
              ", " <<
              orders.inspect
          end
        end

        # :nodoc:
        def self.generate_index_name(table, fields, name)
          if name.is_a?(String)
            name
          else
            [table.to_s].concat(fields.map(&.to_s)).concat(["idx"]).join("_")
          end
        end
      end
    end
  end
end
