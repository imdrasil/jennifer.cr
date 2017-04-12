module Jennifer
  module Migration
    abstract class Base
      REGISTERED_MIGRATIONS = [] of typeof(self)
      TABLE_NAME            = "migration_versions"

      abstract def up
      abstract def down

      def self.version
        to_s[-17..-1]
      end

      def create(name, id = true)
        tb = TableBuilder::CreateTable.new(name)
        tb.integer(:id, {:primary => true, :auto_increment => true}) if id
        yield tb
        tb.process
      end

      def create_join_table(table1, table2, table_name : String? = nil)
        create(table_name || Adapter.adapter_class.join_table_name(table1, table2), false) do |tb|
          tb.integer(table1.to_s.singularize.foreign_key)
          tb.integer(table2.to_s.singularize.foreign_key)
          yield tb
        end
      end

      def create_join_table(table1, table2, table_name : String? = nil)
        create_join_table(table1, table2, table_name) { }
      end

      def drop_join_table(table1, table2)
        drop(Adapter.adapter_class.join_table_name(table1, table2))
      end

      def exec(string)
        TableBuilder::Raw.new(string).process
      end

      def drop(name)
        TableBuilder::DropTable.new(name).process
      end

      def change(name)
        tb = TableBuilder::ChangeTable.new(name)
        yield tb
        tb.process
      end

      def self.versions
        REGISTERED_MIGRATIONS.map { |e| e.underscore.split("_").last }
      end

      macro inherited
        REGISTERED_MIGRATIONS << {{@type}}
      end
    end
  end
end
