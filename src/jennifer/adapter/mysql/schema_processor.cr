require "../schema_processor"

module Jennifer
  module Mysql
    class SchemaProcessor < Adapter::SchemaProcessor
      def rename_table(old_name, new_name)
        adapter.exec "ALTER TABLE #{old_name.to_s} RENAME #{new_name.to_s}"
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
  end
end
