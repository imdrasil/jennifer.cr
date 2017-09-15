module Jennifer
  module Migration
    class Version < Model::Base
      table_name "migration_versions"
      mapping(
        id: {type: Int32, primary: true},
        version: String
      )

      def self.has_table?
        false
      end
    end
  end
end
