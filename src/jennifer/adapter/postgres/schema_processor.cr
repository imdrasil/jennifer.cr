require "../schema_processor"

module Jennifer
  module Postgres
    class SchemaProcessor < Adapter::SchemaProcessor
      delegate data_type_exists?, to: adapter.as(Postgres)

      # ================
      # Builder methods
      # ================

      def build_create_enum(name, values)
        Migration::TableBuilder::CreateEnum.new(@adapter, name, values).process
      end

      def build_drop_enum(name)
        Migration::TableBuilder::DropEnum.new(@adapter, name).process
      end

      def build_change_enum(name, options)
        Migration::TableBuilder::ChangeEnum.new(@adapter, name, options).process
      end

      def build_create_materialized_view(name, _as)
        Migration::TableBuilder::CreateMaterializedView.new(@adapter, name, _as).process
      end

      def build_drop_materialized_view(name)
        Migration::TableBuilder::DropMaterializedView.new(@adapter, name).process
      end

      # ============================
      # Schema manipulating methods
      # ============================

      # TODO: sanitize query
      def define_enum(name, values)
        adapter.exec "CREATE TYPE #{name} AS ENUM(#{values.as(Array).map { |e| "'#{e}'" }.join(", ")})"
      end

      def drop_enum(name)
        adapter.exec "DROP TYPE #{name}"
      end

      def drop_index(table, name)
        adapter.exec "DROP INDEX #{name}"
      end

      # =========== overrides

      def add_index(table, name, fields : Array, type : Symbol? = nil, order : Hash? = nil, length : Hash? = nil)
        query = String.build do |s|
          s << "CREATE "

          s << index_type_translate(type) if type

          s << "INDEX " << name << " ON " << table
          # TODO: add using option to migration
          # s << " USING " << options[:using] if options.has_key?(:using)
          s << " ("
          fields.each_with_index do |f, i|
            s << "," if i != 0
            s << f
            s << " " << order[f].to_s.upcase if order && order[f]?
          end
          s << ")"
          # TODO: add partial support to migration
          # s << " " << options[:partial] if options.has_key?(:partial)
        end
        adapter.exec query
      end

      def change_column(table, old_name, new_name, opts)
        column_name_part = " ALTER COLUMN #{old_name} "
        query = String.build do |s|
          s << "ALTER TABLE " << table
          if opts[:type]?
            s << column_name_part << " TYPE "
            column_type_definition(opts, s)
            s << ","
          end
          if opts[:null]?
            s << column_name_part
            if opts[:null]
              s << " DROP NOT NULL"
            else
              s << " SET NOT NULL"
            end
            s << ","
          end
          if opts[:default]?
            s << column_name_part
            if opts[:default].is_a?(Symbol) && opts[:default].as(Symbol) == :drop
              s << "DROP DEFAULT "
            else
              s << "SET DEFAULT " << adapter_class.t(opts[:default])
            end
            s << ","
          end
          if old_name.to_s != new_name.to_s
            s << " RENAME COLUMN " << old_name << " TO " << new_name
            s << ","
          end
        end

        adapter.exec query[0...-1]
      end

      private def column_definition(name, options, io)
        io << name
        column_type_definition(options, io)
        if options.has_key?(:null)
          if options[:null]
            io << " NULL"
          else
            io << " NOT NULL"
          end
        end
        io << " PRIMARY KEY" if options[:primary]?
        io << " DEFAULT #{adapter_class.t(options[:default])}" if options[:default]?
      end

      private def column_type_definition(options, io)
        size = options[:size]? || adapter.default_type_size(options[:type]?)
        io << " " << column_type(options)
        io << "(#{size})" if size
        io << " ARRAY" if options[:array]?
      end

      private def index_type_translate(name)
        case name
        when :unique, :uniq
          "UNIQUE "
        when nil
          " "
        else
          raise ArgumentError.new("Unknown index type: #{name}")
        end
      end

      private def column_type(options)
        if options[:serial]? || options[:auto_increment]?
          options[:type] == :bigint ? "bigserial" : "serial"
        else
          options[:sql_type]? || adapter.translate_type(options[:type].as(Symbol))
        end
      end
    end
  end
end
