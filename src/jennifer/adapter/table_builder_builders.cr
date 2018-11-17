module Jennifer
  module Adapter
    module TableBuilderBuilders
      def build_create_table(name, id = true)
        tb = Migration::TableBuilder::CreateTable.new(@adapter, name)
        tb.integer(:id, {:primary => true, :auto_increment => true}) if id
        yield tb
        tb.process
      end

      # Creates join table; raises table builder to given block
      def build_create_join_table(table1, table2, table_name : String? = nil)
        build_create_table(table_name || adapter_class.join_table_name(table1, table2), false) do |tb|
          tb.integer(Inflector.foreign_key(Inflector.singularize(table1.to_s)))
          tb.integer(Inflector.foreign_key(Inflector.singularize(table2.to_s)))
          yield tb
        end
      end

      # Creates join table.
      def build_create_join_table(table1, table2, table_name : String? = nil)
        build_create_join_table(table1, table2, table_name) { }
      end

      def build_drop_join_table(table1, table2)
        build_drop_table(@adapter.class.join_table_name(table1, table2))
      end

      def build_exec(string)
        Migration::TableBuilder::Raw.new(@adapter, string).process
      end

      def build_drop_table(name)
        Migration::TableBuilder::DropTable.new(@adapter, name).process
      end

      def build_change_table(name)
        tb = Migration::TableBuilder::ChangeTable.new(@adapter, name)
        yield tb
        tb.process
      end

      def build_create_view(name, source)
        Migration::TableBuilder::CreateView.new(@adapter, name.to_s, source).process
      end

      def build_drop_view(name)
        Migration::TableBuilder::DropView.new(@adapter, name.to_s).process
      end

      def build_add_index(table_name, name : String, fields : Array(Symbol), type : Symbol, lengths : Hash(Symbol, Int32) = {} of Symbol => Int32, orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
        Migration::TableBuilder::CreateIndex.new(@adapter, table_name, name, fields, type, lengths, orders).process
      end

      def build_add_index(table_name, name : String, field : Symbol, type : Symbol, length : Int32? = nil, order : Symbol? = nil)
        build_add_index(
          table_name,
          name,
          [field],
          type: type,
          orders: (order ? {field => order.not_nil!} : {} of Symbol => Symbol),
          lengths: (length ? {field => length.not_nil!} : {} of Symbol => Int32)
        )
      end

      def build_drop_index(table_name, name)
        Migration::TableBuilder::DropIndex.new(@adapter, table_name, name).process
      end

      def build_add_foreign_key(from_table, to_table, column = nil, primary_key = nil, name = nil)
        Migration::TableBuilder::CreateForeignKey.new(@adapter, from_table.to_s, to_table.to_s, column, primary_key, name).process
      end

      def build_drop_foreign_key(from_table, to_table, name = nil)
        Migration::TableBuilder::DropForeignKey.new(@adapter, from_table.to_s, to_table.to_s, name).process
      end
    end
  end
end
