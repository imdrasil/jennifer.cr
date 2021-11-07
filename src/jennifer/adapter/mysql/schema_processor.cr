require "../schema_processor"

module Jennifer
  module Mysql
    class SchemaProcessor < Adapter::SchemaProcessor
      def rename_table(old_name, new_name)
        adapter.exec "ALTER TABLE #{old_name} RENAME #{new_name}"
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

      private def column_definition(name, options, io) # ameba:disable Metrics/CyclomaticComplexity
        size = options[:size]? || adapter.default_type_size(options[:type])
        io << name << " " << column_type(options)
        io << "(#{size})" if size
        if options[:type] == :enum
          io << " ("
          options[:values].as(Array).each_with_index do |e, i|
            io << ", " if i != 0
            io << "'#{e.as(String | Symbol)}'"
          end
          io << ") "
        end
        if options[:generated]?
          io << " AS (" << options[:as] << ')'
          io << " STORED" if options[:stored]
        end
        if options.has_key?(:null)
          io << " NOT" unless options[:null]
          io << " NULL"
        end
        io << " PRIMARY KEY" if options.has_key?(:primary) && options[:primary]
        io << " DEFAULT #{adapter_class.t(options[:default])}" if options.has_key?(:default)
        io << " AUTO_INCREMENT" if options.has_key?(:auto_increment) && options[:auto_increment]
      end

      def column_type(options : Hash)
        if options[:serial]?
          "serial"
        elsif options.has_key?(:sql_type)
          options[:sql_type]
        else
          type = options[:type]
          if type == :decimal
            scale_opts = [] of Int32
            if options.has_key?(:precision)
              scale_opts << options[:precision].as(Int32)
              scale_opts << options[:scale].as(Int32) if options.has_key?(:scale)
            end

            String.build do |io|
              io << "numeric"
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
    end
  end
end
