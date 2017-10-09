require "yaml"
require "logger"

module Jennifer
  class Config
    CONNECTION_URI_PARAMS = [:max_pool_size, :initial_pool_size, :max_idle_pool_size, :retry_attempts, :checkout_timeout, :retry_delay]
    STRING_FIELDS = {:user, :password, :db, :host, :adapter, :migration_files_path, :schema, :structure_folder}
    INT_FIELDS    = {:port, :max_pool_size, :initial_pool_size, :max_idle_pool_size, :retry_attempts}
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
    define_fields(INT_FIELDS, 0)
    define_fields(FLOAT_FIELDS, 0.0)

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

    def self.reset_config
      @@adapter = "postgres"
      @@host = "localhost"
      @@port = -1
      @@migration_files_path = "./db/migrations"
      @@schema = "public"
      @@db = ""

      @@initial_pool_size = 1
      @@max_pool_size = 5
      @@max_idle_pool_size = 1
      @@retry_attempts = 1

      @@checkout_timeout = 5.0
      @@retry_delay = 1.0

      @@logger = Logger.new(STDOUT)
      @@logger.not_nil!.level = Logger::DEBUG
      @@logger.not_nil!.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
        io << datetime << ": " << message
      end
    end

    reset_config

    def self.logger
      @@logger.not_nil!
    end

    def self.logger=(value)
      @@logger = value
    end

    def self.configure(&block)
      yield self
      self.validate_config
    end

    def self.validate_config
      raise Jennifer::InvalidConfig.new("No adapter configured") if adapter.empty?
      raise Jennifer::InvalidConfig.new("No database configured") if db.empty?
    end

    def self.configure
      self
    end

    def self.config
      self
    end

    def self.from_uri(db_uri : String)
      begin
        from_uri(URI.parse(db_uri))
      rescue e
        self.logger.error("Error parsing database uri #{db_uri}")
      end
    end

    def self.from_uri(uri : URI)
      config.adapter = uri.scheme.to_s if uri.scheme
      config.host = uri.host.to_s if uri.host
      config.port = uri.port.not_nil!  if uri.port
      config.db = uri.path.to_s.lchop if uri.path
      config.user = uri.user.to_s if uri.user
      config.password = uri.password.to_s if uri.password

      if uri.query
        params = HTTP::Params.parse(uri.query.to_s)
        {% for field in CONNECTION_URI_PARAMS %}
          {% if STRING_FIELDS.includes?(field) %}
              @@{{field.id}} = params["{{field.id}}"] if params["{{field.id}}"]?
          {% end %}
          {% if INT_FIELDS.includes?(field) %}
              @@{{field.id}} = params["{{field.id}}"].to_i if params["{{field.id}}"]?
          {% end %}
          {% if FLOAT_FIELDS.includes?(field) %}
              @@{{field.id}} = params["{{field.id}}"].to_f if params["{{field.id}}"]?
          {% end %}
        {% end %}
      end
      self.validate_config
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
      self.validate_config
      self
    end
  end
end
