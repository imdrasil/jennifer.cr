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
