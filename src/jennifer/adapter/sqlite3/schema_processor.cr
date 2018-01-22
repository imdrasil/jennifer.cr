require "../schema_processor"

module Jennifer
  module Sqlite3
    class SchemaProcessor < Adapter::SchemaProcessor
      # ============================
      # Schema manipulating methods
      # ============================

      def rename_table(old_name, new_name)
        exec "ALTER TABLE #{old_name.to_s} RENAME TO #{new_name.to_s}"
      end

      def drop_index(table, name)
        exec "DROP INDEX #{name}"
      end

      def change_column(table, old_name, new_name, opts)
        raise "ALTER COLUMN is not implemented yet. Take a look on this http://www.sqlite.org/faq.html#q11"
      end

      def drop_column(table, old_name, new_name, opts)
        raise "DROP COLUMN is not implemented yet. Take a look on this http://www.sqlite.org/faq.html#q11"
      end

      private def column_definition(name, options, io)
        type = options[:sql_type]? || translate_type(options[:type].as(Symbol))
        size = options[:size]? || default_type_size(options[:type])
        io << name << " " << type
        io << "(#{size})" if size
        if options.key?(:null)
          if options[:null]
            io << " NULL"
          else
            io << " NOT NULL"
          end
        end
        io << " PRIMARY KEY" if options[:primary]?
        io << " DEFAULT #{self.class.t(options[:default])}" if options[:default]?
        io << " AUTOINCREMENT" if options[:auto_increment]?
      end
    end
  end
end
