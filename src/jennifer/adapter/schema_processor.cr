require "../migration/table_builder/*"

module Jennifer
  module Adapter
    class SchemaProcessor
      macro unsupported_method(*names)
        {% for name in names %}
          def {{name.id}}(*args, **opts)
            raise BaseException.new("Current adapter doesn't support this method: #{{{name.id}}}")
          end
        {% end %}
      end

      unsupported_method build_create_enum, build_drop_enum, build_change_enum, build_create_materialized_view,
        build_drop_materialized_view, drop_enum

      getter adapter : Adapter::Base

      def initialize(@adapter)
      end

      # ================
      # Builder methods
      # ================

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

      # ============================
      # Schema manipulating methods
      # ============================

      def rename_table(old_name, new_name)
        adapter.exec "ALTER TABLE #{old_name.to_s} RENAME #{new_name.to_s}"
      end

      def add_index(table, name, fields : Array, type : Symbol? = nil, order : Hash? = nil, length : Hash? = nil)
        query = String.build do |s|
          s << "CREATE "

          s << index_type_translate(type) if type

          s << "INDEX " << name << " ON " << table << "("
          fields.each_with_index do |f, i|
            s << "," if i != 0
            s << f
            s << "(" << length[f] << ")" if length && length[f]?
            s << " " << order[f].to_s.upcase if order && order[f]?
          end
          s << ")"
        end
        adapter.exec query
      end

      def drop_index(table, name)
        adapter.exec "DROP INDEX #{name} ON #{table}"
      end

      def drop_column(table, name)
        adapter.exec "ALTER TABLE #{table} DROP COLUMN #{name}"
      end

      def add_column(table, name, opts)
        query = String.build do |s|
          s << "ALTER TABLE " << table << " ADD COLUMN "
          column_definition(name, opts, s)
        end

        adapter.exec query
      end

      def change_column(table, old_name, new_name, opts)
        query = String.build do |s|
          s << "ALTER TABLE " << table << " CHANGE COLUMN " << old_name << " "
          column_definition(new_name, opts, s)
        end

        adapter.exec query
      end

      def drop_table(builder : Migration::TableBuilder::DropTable)
        adapter.exec "DROP TABLE #{builder.name}"
      end

      def create_table(builder : Migration::TableBuilder::CreateTable)
        buffer = String.build do |s|
          s << "CREATE TABLE " << builder.name << " ("
          builder.fields.each_with_index do |(name, options), i|
            s << ", " if i != 0
            column_definition(name, options, s)
          end
          s << ")"
        end
        adapter.exec buffer
      end

      def create_view(name, query, silent = true)
        buff = String.build do |s|
          s << "CREATE "
          s << "OR REPLACE " if silent
          s << "VIEW " << name << " AS " << adapter.sql_generator.select(query)
        end
        args = query.select_args
        adapter.exec *adapter.parse_query(buff, args)
      end

      def drop_view(name, silent = true)
        buff = String.build do |s|
          s << "DROP VIEW "
          s << "IF EXISTS " if silent
          s << name
        end
        adapter.exec buff
      end

      def add_foreign_key(from_table, to_table, column, primary_key, name)
        query = String.build do |s|
          s << "ALTER TABLE " << from_table
          s << " ADD CONSTRAINT " << name
          s << " FOREIGN KEY (" << column << ") REFERENCES "
          s << to_table << "(" << primary_key << ")"
        end
        adapter.exec query
      end

      def drop_foreign_key(from_table, name)
        query = String.build do |s|
          s << "ALTER TABLE " << from_table
          s << "DROP FOREIGN KEY " << name
        end
        adapter.exec query
      end

      private def adapter_class
        @adapter.class
      end

      # NOTE: adding here type will bring a lot of small issues around

      private def index_type_translate(name)
        case name
        when :unique, :uniq
          "UNIQUE "
        when :fulltext
          "FULLTEXT "
        when :spatial
          "SPATIAL "
        when nil
          " "
        else
          raise ArgumentError.new("Unknown index type: #{name}")
        end
      end

      private def column_definition(name, options, io)
        type = options[:serial]? ? "serial" : (options[:sql_type]? || adapter.translate_type(options[:type].as(Symbol)))
        size = options[:size]? || adapter.default_type_size(options[:type])
        io << name << " " << type
        io << "(#{size})" if size
        if options[:type] == :enum
          io << " ("
          options[:values].as(Array).each_with_index do |e, i|
            io << ", " if i != 0
            io << "'#{e.as(String | Symbol)}'"
          end
          io << ") "
        end
        if options.has_key?(:null)
          if options[:null]
            io << " NULL"
          else
            io << " NOT NULL"
          end
        end
        io << " PRIMARY KEY" if options[:primary]?
        io << " DEFAULT #{adapter_class.t(options[:default])}" if options[:default]?
        io << " AUTO_INCREMENT" if options[:auto_increment]?
      end
    end

    # NOTE: because of cyclic dependency this is the easiest solution ATM

    class Base
      def schema_processor
        @schema_processor ||= SchemaProcessor.new(self)
      end
    end
  end
end
