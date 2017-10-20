require "yaml"
require "logger"

module Jennifer
  class Config
    CONNECTION_URI_PARAMS = [:max_pool_size, :initial_pool_size, :max_idle_pool_size, :retry_attempts, :checkout_timeout, :retry_delay]

    class ConfigInstance
      STRING_FIELDS = {:adapter, :user, :password, :db, :host, :adapter, :migration_files_path, :schema, :structure_folder, :key}
      INT_FIELDS    = {:port, :max_pool_size, :initial_pool_size, :max_idle_pool_size, :retry_attempts}
      FLOAT_FIELDS  = [:checkout_timeout, :retry_delay]

      macro define_fields(const, default)
        {% for field in @type.constant(const.stringify) %}
        @{{field.id}} = {{default}}

        def {{field.id}}=(value)
          @{{field.id}} = value
        end

        def {{field.id}}
          @{{field.id}}
        end
      {% end %}
      end

      define_fields(STRING_FIELDS, default: "")
      define_fields(INT_FIELDS, default: 0)
      define_fields(FLOAT_FIELDS, default: 0.0)

      def initialize
        @adapter = "postgres"
        @host = "localhost"
        @port = -1
        @migration_files_path = "./db/migrations"
        @schema = "public"
        @db = ""
        @key = "default"

        @initial_pool_size = 1
        @max_pool_size = 5
        @max_idle_pool_size = 1
        @retry_attempts = 1

        @checkout_timeout = 5.0
        @retry_delay = 1.0

        @logger = Logger.new(STDOUT)
        @logger.not_nil!.level = Logger::DEBUG
        @logger.not_nil!.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
          io << datetime << ": " << message
        end
      end

      def structure_folder
        if @structure_folder.empty?
          File.dirname(@migration_files_path)
        else
          @structure_folder
        end
      end

      def structure_path
        File.join(self.structure_folder, "structure.sql")
      end

      def logger
        @logger.not_nil!
      end

      def logger=(value)
        @logger = value
      end

      def validate_config
        raise Jennifer::InvalidConfig.new("No adapter configured") if adapter.empty?
        raise Jennifer::InvalidConfig.new("No database configured") if db.empty?
      end

      def connection_string(*options)
        auth_part = @user
        auth_part += ":#{@password}" if @password && !@password.empty?

        host_part = @host
        host_part += ":#{@port}" if @port && @port > 0

        String.build do |s|
          s << @adapter << "://"
          s << auth_part << "@" if auth_part.size > 0
          s << host_part
          s << "/" << @db if options.includes?(:db)
          s << "?"
          {% for arg, index in CONNECTION_URI_PARAMS %}
            s << "{{arg.id}}=#{@{{arg.id}}}"
            s << "&" if {{index}} < {{CONNECTION_URI_PARAMS.size - 1}}
          {% end %}
        end
      end

      def from_uri(db_uri : String)
        begin
          from_uri(URI.parse(db_uri))
        rescue e : URI::Error
          self.logger.error("Error parsing database uri #{db_uri} - #{e.message}")
        end
      end

      def from_uri(uri : URI)
        @adapter = uri.scheme.to_s if uri.scheme
        @host = uri.host.to_s if uri.host
        @port = uri.port.not_nil!  if uri.port
        @db = uri.path.to_s.lchop if uri.path
        @user = uri.user.to_s if uri.user
        @password = uri.password.to_s if uri.password

        if uri.query
          params = HTTP::Params.parse(uri.query.to_s)
          {% for field in CONNECTION_URI_PARAMS %}
            {% if STRING_FIELDS.includes?(field) %}
                @{{field.id}} = params["{{field.id}}"] if params["{{field.id}}"]?
            {% end %}
            {% if INT_FIELDS.includes?(field) %}
                @{{field.id}} = params["{{field.id}}"].to_i if params["{{field.id}}"]?
            {% end %}
            {% if FLOAT_FIELDS.includes?(field) %}
                @{{field.id}} = params["{{field.id}}"].to_f if params["{{field.id}}"]?
            {% end %}
          {% end %}
        end
        validate_config
        self
      end

      def read(path : String, env : String | Symbol = :development)
        _env = env.to_s
        source = YAML.parse(File.read(path))[_env]
        {% for field in STRING_FIELDS %}
          @{{field.id}} = source["{{field.id}}"].as_s if source["{{field.id}}"]?
        {% end %}
        {% for field in INT_FIELDS %}
          @{{field.id}} = source["{{field.id}}"].as_s.to_i if source["{{field.id}}"]?
        {% end %}
        {% for field in FLOAT_FIELDS %}
          @{{field.id}} = source["{{field.id}}"].as_s.to_f if source["{{field.id}}"]?
        {% end %}
        self.validate_config
        self
      end
    end

    @@configs = {} of String => ConfigInstance

    def self.get_instance(config_key : String | Symbol = :default)
      config_key = config_key.to_s
      return @@configs[config_key] if @@configs.has_key?(config_key)
      ConfigInstance.new.tap do |config|
        @@configs[config_key] = config
        config.key = config_key
      end
    end

    def self.reset_config
      @@configs = {} of String => ConfigInstance
    end

    def self.configure(config_name : Symbol = :default, &block)
      config = get_instance(config_name)
      yield config
      config.validate_config
    end

    {%for method in ConfigInstance.methods %}
      {% unless method.name.ends_with?('=') %}
        def self.{{method.name}}({% if method.args.size > 0 %} {{*method.args}} {% end %})
          get_instance(:default).{{method.name}}({{* method.args.map(&.name)}})
        end
      {% end %}
    {% end %}
  end
end
