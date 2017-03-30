require "./support"
require "yaml"
require "logger"

module Jennifer
  class Config
    include Support
    FIELDS = [:user, :password, :db, :host, :adapter, :migration_files_path, :schema]

    {% for field in FIELDS %}
      @@{{field.id}} = ""

      def self.{{field.id}}=(value)
        @@{{field.id}} = value
      end

      def self.{{field.id}}
        @@{{field.id}}
      end
    {% end %}

    @@logger = Logger.new(STDOUT)

    @@logger.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
      io << datetime << ": " << message
    end

    @@logger.level = Logger::DEBUG

    def self.logger
      @@logger
    end

    def self.logger=(value)
      @@logger = value
    end

    @@host = "localhost"
    @@migration_files_path = "./db/migrations"
    @@schema = "public"

    def self.configure(&block)
      yield self
    end

    def self.configure
      self
    end

    def self.config
      self
    end

    def self.read(path : String, env : String | Symbol = :development)
      _env = env.to_s
      source = YAML.parse(File.read(path))[_env]
      {% for field in FIELDS %}
        @@{{field.id}} = source["{{field.id}}"].as_s if source["{{field.id}}"]?
      {% end %}
      self
    end
  end
end
