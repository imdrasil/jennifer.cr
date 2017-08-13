require "yaml"
require "logger"

module Jennifer
  class Config
    STRING_FIELDS = {:user, :password, :db, :host, :adapter, :migration_files_path, :schema, :structure_folder}
    INT_FIELDS    = {:max_pool_size, :initial_pool_size, :max_idle_pool_size, :retry_attempts}
    FLOAT_FIELDS  = [:checkout_timeout, :retry_delay]

    macro define_fields(const, default)
      {% for field in @type.constant(const.stringify) %}
      @@{{field.id}} = {{default}}

      def self.{{field.id}}=(value)
        @@{{field.id}} = value
      end

      def self.{{field.id}}
        @@{{field.id}}
      end
    {% end %}
    end

    define_fields(STRING_FIELDS, default: "")

    def self.structure_folder
      if @@structure_folder.empty?
        File.dirname(@@migration_files_path)
      else
        @@structure_folder
      end
    end

    def self.structure_path
      File.join(Config.structure_folder, "structure.sql")
    end

    @@host = "localhost"
    @@migration_files_path = "./db/migrations"
    @@schema = "public"

    define_fields(INT_FIELDS, 0)
    @@initial_pool_size = 1
    @@max_pool_size = 5
    @@max_idle_pool_size = 1
    @@retry_attempts = 1

    define_fields(FLOAT_FIELDS, 0.0)
    @@checkout_timeout = 5.0
    @@retry_delay = 1.0

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
      {% for field in STRING_FIELDS %}
        @@{{field.id}} = source["{{field.id}}"].as_s if source["{{field.id}}"]?
      {% end %}
      {% for field in INT_FIELDS %}
        @@{{field.id}} = source["{{field.id}}"].as_s.to_i if source["{{field.id}}"]?
      {% end %}
      {% for field in FLOAT_FIELDS %}
        @@{{field.id}} = source["{{field.id}}"].as_s.to_f if source["{{field.id}}"]?
      {% end %}
      self
    end
  end
end
