module Jennifer
  module Migration
    class Version < Model::Base
      table_name "migration_versions"
      mapping(
        id: Primary32,
        version: String
      )

      def self.has_table?
        false
      end

      def self.list
        all.pluck(:version).map(&.as(String))
      end
    end
  end
end
