require "../migration/table_builder/*"

module Jennifer
  module Adapter
    class MigrationProcessor
      macro unsupported_method(*names)
        {% for name in names %}
          def {{name.id}}(*args, **opts)
            raise BaseException.new("Current adapter doesn't support this method: #{{{name.id}}}")
          end
        {% end %}
      end

      unsupported_method create_enum, drop_enum, change_enum, create_materialized_view, drop_materialized_view

      getter adapter : Adapter::Base

      def initialize(@adapter)
      end

      def create_table(name, id = true)
        tb = Migration::TableBuilder::CreateTable.new(@adapter, name)
        tb.integer(:id, {:primary => true, :auto_increment => true}) if id
        yield tb
        tb.process
      end

      # Creates join table; raises table builder to given block
      def create_join_table(table1, table2, table_name : String? = nil)
        create_table(table_name || adapter_class.join_table_name(table1, table2), false) do |tb|
          tb.integer(table1.to_s.singularize.foreign_key)
          tb.integer(table2.to_s.singularize.foreign_key)
          yield tb
        end
      end

      # Creates join table.
      def create_join_table(table1, table2, table_name : String? = nil)
        create_join_table(table1, table2, table_name) { }
      end

      def drop_join_table(table1, table2)
        drop_table(@adapter.class.join_table_name(table1, table2))
      end

      def exec(string)
        Migration::TableBuilder::Raw.new(@adapter, string).process
      end

      def drop_table(name)
        Migration::TableBuilder::DropTable.new(@adapter, name).process
      end

      def change_table(name)
        tb = Migration::TableBuilder::ChangeTable.new(@adapter, name)
        yield tb
        tb.process
      end

      def create_view(name, source)
        Migration::TableBuilder::CreateView.new(@adapter, name.to_s, source).process
      end

      def drop_view(name)
        Migration::TableBuilder::DropView.new(@adapter, name.to_s).process
      end

      def add_index(table_name, name : String, fields : Array(Symbol), type : Symbol, lengths : Hash(Symbol, Int32) = {} of Symbol => Int32, orders : Hash(Symbol, Symbol) = {} of Symbol => Symbol)
        Migration::TableBuilder::CreateIndex.new(@adapter, table_name, name, fields, type, lengths, orders).process
      end

      def add_index(table_name, name : String, field : Symbol, type : Symbol, length : Int32? = nil, order : Symbol? = nil)
        add_index(
          table_name,
          name,
          [field],
          type: type,
          orders: (order ? {field => order.not_nil!} : {} of Symbol => Symbol),
          lengths: (length ? {field => length.not_nil!} : {} of Symbol => Int32)
        )
      end

      def drop_index(table_name, name)
        Migration::TableBuilder::DropIndex.new(@adapter, table_name, name).process
      end

      private def adapter_class
        @adapter.class
      end
    end

    class Base
      def migration_processor
        @migration_processor ||= MigrationProcessor.new(self)
      end
    end
  end
end
