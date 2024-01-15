require "../migration/table_builder/*"

module Jennifer
  module Adapter
    abstract class SchemaProcessor
      enum FkEventActions
        Restrict
        Cascade
        SetNull
        NoAction
      end

      ON_EVENT_ACTION_TRANSLATIONS = {
        FkEventActions::NoAction => "NO ACTION",
        FkEventActions::Restrict => "RESTRICT",
        FkEventActions::Cascade  => "CASCADE",
        FkEventActions::SetNull  => "SET NULL",
      }

      # :nodoc:
      macro unsupported_method(*names)
        {% for name in names %}
          # :nodoc:
          def {{name.id}}(*args, **opts)
            raise BaseException.new("Current adapter doesn't support this method: #{{{name.id}}}")
          end
        {% end %}
      end

      unsupported_method build_create_enum, build_drop_enum, build_change_enum, build_create_materialized_view,
        build_drop_materialized_view, drop_enum, enum_exists?

      getter adapter : Adapter::Base

      def initialize(@adapter)
      end

      abstract def rename_table(old_name : String | Symbol, new_name : String | Symbol)
      private abstract def index_type_translate(name)
      private abstract def column_definition(name, options, io)

      def add_index(table, name, fields : Array, type : Symbol? = nil, order : Hash? = nil, length : Hash? = nil)
        query = String.build do |io|
          io << "CREATE "

          io << index_type_translate(type) if type

          io << "INDEX " << name << " ON " << table << " ("
          fields.each_with_index do |field, i|
            io << "," if i != 0
            io << field
            io << "(" << length[field] << ")" if length && length[field]?
            io << " " << order[field].to_s.upcase if order && order[field]?
          end
          io << ")"
        end
        adapter.exec query
      end

      def drop_index(table, name)
        adapter.exec "DROP INDEX #{name} ON #{table}"
      end

      def drop_column(table, name)
        adapter.exec "ALTER TABLE #{table} DROP COLUMN #{name}"
      end

      def add_column(table, name, opts : Hash)
        query = String.build do |io|
          io << "ALTER TABLE " << table << " ADD COLUMN "
          column_definition(name, opts, io)
        end

        adapter.exec query
      end

      def change_column(table, old_name, new_name, opts : Hash)
        query = String.build do |io|
          io << "ALTER TABLE " << table << " CHANGE COLUMN " << old_name << " "
          column_definition(new_name, opts, io)
        end

        adapter.exec query
      end

      def drop_table(builder : Migration::TableBuilder::DropTable)
        adapter.exec "DROP TABLE #{builder.name}"
      end

      def create_table(builder : Migration::TableBuilder::CreateTable)
        buffer = String.build do |io|
          io << "CREATE TABLE " << builder.name << " ("
          builder.fields.each_with_index do |(name, options), i|
            io << ", " if i != 0
            column_definition(name, options, io)
          end
          io << ")"
        end
        adapter.exec buffer
      end

      def create_view(name, query, silent = true)
        buff = String.build do |io|
          io << "CREATE "
          io << "OR REPLACE " if silent
          io << "VIEW " << name << " AS " << adapter.sql_generator.select(query)
        end
        args = query.sql_args
        adapter.exec *adapter.parse_query(buff, args)
      end

      def drop_view(name, silent = true)
        buff = String.build do |io|
          io << "DROP VIEW "
          io << "IF EXISTS " if silent
          io << name
        end
        adapter.exec buff
      end

      def add_foreign_key(from_table, to_table, column, primary_key, name, on_update, on_delete)
        on_delete = FkEventActions.parse(on_delete.to_s)
        on_update = FkEventActions.parse(on_update.to_s)
        query = String.build do |io|
          io << "ALTER TABLE " << from_table
          io << " ADD CONSTRAINT " << name
          io << " FOREIGN KEY (" << column << ") REFERENCES "
          io << to_table << "(" << primary_key << ")"
          io << " ON UPDATE " << ON_EVENT_ACTION_TRANSLATIONS[on_update]
          io << " ON DELETE " << ON_EVENT_ACTION_TRANSLATIONS[on_delete]
        end
        adapter.exec query
      end

      def drop_foreign_key(from_table, _to_table, name)
        query = String.build do |io|
          io << "ALTER TABLE " <<
            from_table <<
            " DROP FOREIGN KEY " <<
            name
        end
        adapter.exec query
      end

      private def adapter_class
        @adapter.class
      end
    end
  end
end
