module Jennifer
  module Migration
    # :nodoc:
    class Version < Model::Base
      table_name "migration_versions"

      mapping({
        version: {type: String, primary: true, auto: false, null: false},
      }, false)

      @@adapter : Adapter::Base?

      def self.adapter
        @@adapter.not_nil!
      end

      def self.adapter=(adapter : Adapter::Base)
        @@adapter = adapter
        adapter
      end

      def self.has_table?
        false
      end

      def self.list
        all.pluck(:version).map(&.as(String))
      end
    end
  end
end
