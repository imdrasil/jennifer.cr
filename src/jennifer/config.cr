require "./support"

module Jennifer
  class Config
    include Support

    {% for field in [:user, :password, :db, :host, :adapter, :migration_files_path, :schema] %}
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
    @@schema = "public"

    def self.configure(&block)
      yield self
    end

    def self.configure
      self
    end
  end
end
