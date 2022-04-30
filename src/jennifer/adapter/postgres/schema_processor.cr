require "../schema_processor"

module Jennifer
  module Postgres
    class SchemaProcessor < Adapter::SchemaProcessor
      delegate enum_exists?, to: adapter.as(Postgres)

      # ================
      # Builder methods
      # ================

      def build_create_enum(name, values)
        Migration::TableBuilder::CreateEnum.new(@adapter, name, values)
      end

      def build_drop_enum(name)
        Migration::TableBuilder::DropEnum.new(@adapter, name)
      end

      def build_change_enum(name, options)
        Migration::TableBuilder::ChangeEnum.new(@adapter, name, options)
      end

      def build_create_materialized_view(name, source)
        Migration::TableBuilder::CreateMaterializedView.new(@adapter, name, source)
      end

      def build_drop_materialized_view(name)
        Migration::TableBuilder::DropMaterializedView.new(@adapter, name)
      end

      # ============================
      # Schema manipulating methods
      # ============================

      def define_enum(name : String | Symbol, values : Array)
        adapter.exec "CREATE TYPE #{name} AS ENUM(#{values.map { |e| adapter.sql_generator.quote(e) }.join(", ")})"
      end

      def drop_enum(name)
        adapter.exec "DROP TYPE #{name}"
      end

      def drop_index(table, name)
        adapter.exec "DROP INDEX #{name}"
      end

      def rename_table(old_name : String | Symbol, new_name : String | Symbol)
        adapter.exec "ALTER TABLE #{old_name} RENAME TO #{new_name}"
      end

      # =========== overrides

      def add_index(table, name, fields : Array, type : Symbol? = nil, order : Hash? = nil, length : Hash? = nil)
        query = String.build do |s|
          s << "CREATE "

          s << index_type_translate(type) if type

          s << "INDEX " << name << " ON " << table
          # s << " USING " << options[:using] if options.has_key?(:using)
          s << " ("
          fields.each_with_index do |f, i|
            s << "," if i != 0
            s << f
            s << " " << order[f].to_s.upcase if order && order[f]?
          end
          s << ")"
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
            change_column_type_definition(opts, s)
            s << ","
          end
          if opts[:null]?
            s << column_name_part
            s << opts[:null] ? " DROP" : " SET"
            s << " NOT NULL,"
          end
          if opts.has_key?(:default)
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

      def drop_foreign_key(from_table, _to_table, name)
        query = String.build do |s|
          s << "ALTER TABLE " <<
            from_table <<
            " DROP CONSTRAINT " <<
            name
        end
        adapter.exec query
      end

      private def column_definition(name, options, io)
        io << name
        column_type_definition(options, io)
        if options[:generated]?
          raise ArgumentError.new("not stored generated columns are not supported yet") unless options[:stored]

          io << " GENERATED ALWAYS AS (" << options[:as] << ") STORED"
        end
        if options.has_key?(:null)
          io << " NOT" unless options[:null]
          io << " NULL"
        end
        io << " PRIMARY KEY" if options.has_key?(:primary) && options[:primary]
        io << " DEFAULT #{adapter_class.t(options[:default])}" if options.has_key?(:default)
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

      private def column_type(options : Hash)
        if options[:serial]? || options[:auto_increment]?
          options[:type] == :bigint ? "bigserial" : "serial"
        elsif options.has_key?(:sql_type)
          options[:sql_type]
        else
          type = options[:type]
          if type == :numeric || type == :decimal
            scale_opts = [] of Int32
            if options.has_key?(:precision)
              scale_opts << options[:precision].as(Int32)
              scale_opts << options[:scale].as(Int32) if options.has_key?(:scale)
            end
            String.build do |io|
              type.to_s(io)
              next if scale_opts.empty?

              io << '('
              scale_opts.join(io, ',')
              io << ')'
            end
          else
            adapter.translate_type(type.as(Symbol))
          end
        end
      end

      private def change_column_type_definition(opts, s)
        if opts[:auto_increment]? && (opts[:type] == :bigint || opts[:type] == :int)
          opts[:type].to_s(s)
        else
          column_type_definition(opts, s)
        end
      end
    end
  end
end
