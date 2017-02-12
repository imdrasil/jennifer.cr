require "./support"

module Jennifer
  class Config
    include Support

    {% for field in [:user, :password, :db, :host, :adapter, :migration_files_path] %}
      @@{{field.id}} = ""

      def self.{{field.id}}=(value)
        @@{{field.id}} = value
      end

      def self.{{field.id}}
        @@{{field.id}}
      end
    {% end %}

    @@host = "localhost"
    @@migration_files_path = "./db/migrations"
    @@adapter = "mysql"

    def self.configure
      yield self
    end
  end
end
