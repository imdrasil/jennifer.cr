require "yaml"
require "logger"

module Jennifer
  class Config
    CONNECTION_URI_PARAMS = [
      :max_pool_size, :initial_pool_size, :max_idle_pool_size,
      :retry_attempts, :checkout_timeout, :retry_delay
    ]
    STRING_FIELDS = {
      :user, :password, :db, :host, :adapter, :migration_files_path, :schema,
      :structure_folder, :local_time_zone_name, :command_shell, :docker_container, :docker_source_location,
      :migration_failure_handler_method
    }
    INT_FIELDS    = {:port, :max_pool_size, :initial_pool_size, :max_idle_pool_size, :retry_attempts}
    FLOAT_FIELDS  = {:checkout_timeout, :retry_delay}
    BOOL_FIELDS   = {:command_shell_sudo, :skip_dumping_schema_sql}
    ALLOWED_MIGRATION_FAILURE_HANDLER_METHODS = %w(reverse_direction callback none)

    macro define_fields(const, default)
      {% for field in const.resolve %}
        @{{field.id}} = {{default}}
        property {{field.id}}
        delegate_property {{field.id}}
      {% end %}
    end

    macro delegate_setter(*methods)
      {% for method in methods %}
        def self.{{method.id}}=(value)
          instance.{{method.id}}= value
        end
      {% end %}
    end

    macro delegate_getter(*methods)
      {% for method in methods %}
        def self.{{method.id}}
          instance.{{method.id}}
        end
      {% end %}
    end

    macro delegate_property(*methods)
      delegate_getter({{*methods}})
      delegate_setter({{*methods}})
    end

    define_fields(STRING_FIELDS, "")
    define_fields(INT_FIELDS, 0)
    define_fields(FLOAT_FIELDS, 0.0)
    define_fields(BOOL_FIELDS, false)

    @local_time_zone : Time::Location

    @@instance = new

    def initialize
      @adapter = "postgres"
      @host = "localhost"
      @port = -1
      @migration_files_path = "./db/migrations"
      @schema = "public"
      @local_time_zone_name = Time::Location.local.name
      @local_time_zone = Time::Location.local

      # NOTE: Uncomment common default values after resolving https://github.com/crystal-lang/crystal-db/issues/77

      # @initial_pool_size = 1
      # @max_pool_size = 5
      # @max_idle_pool_size = 1

      @initial_pool_size = 1
      @max_pool_size = 1
      @max_idle_pool_size = 1

      @retry_attempts = 1

      @checkout_timeout = 5.0
      @retry_delay = 1.0

      @command_shell = "bash"
      @migration_after_failure_method = "none"

      @logger = Logger.new(STDOUT)
      logger.level = Logger::DEBUG
      logger.formatter = Logger::Formatter.new do |_severity, datetime, _progname, message, io|
        io << datetime << ": " << message
      end
    end

    def self.instance
      @@instance
    end

    def self.configure
      instance
    end

    def self.config
      instance
    end

    def structure_folder
      if @structure_folder.empty?
        File.dirname(@migration_files_path)
      else
        @structure_folder
      end
    end

    def structure_path
      File.join(structure_folder, "structure.sql")
    end

    delegate_getter(:structure_path)

    def self.reset_config
      @@instance = new
    end

    def logger
      @logger.not_nil!
    end

    def logger=(value)
      @logger = value
    end

    delegate_property(:logger)

    def local_time_zone_name=(value : String)
      @local_time_zone_name = value
      @local_time_zone = Time::Location.load(value)
      value
    end

    def local_time_zone
      @local_time_zone
    end

    delegate_getter(:local_time_zone)

    def self.migration_failure_handler_method=(value)
      parsed_value = value.to_s
      unless ALLOWED_MIGRATION_FAILURE_HANDLER_METHODS.includes?(parsed_value)
        allowed_methods = ALLOWED_MIGRATION_FAILURE_HANDLER_METHODS.map { |e| %("#{e}") }.join(" ")
        raise Jennifer::InvalidConfig.new(
          %(migration_failure_handler_method config may be only #{allowed_methods})
        )
      end
      @@migration_failure_handler_method = parsed_value
    end

    def self.configure(&block)
      yield instance
      instance.validate_config
    end

    def validate_config
      raise Jennifer::InvalidConfig.new("No adapter configured") if adapter.empty?
      raise Jennifer::InvalidConfig.new("No database configured") if db.empty?
      if max_idle_pool_size != max_pool_size || max_pool_size != initial_pool_size
        logger.warn("It is highly recommended to set max_idle_pool_size = max_pool_size = initial_pool_size to "\
                    "prevent blowing up count of DB connections. For any details take a look at "\
                    "https://github.com/crystal-lang/crystal-db/issues/77")
      end
    end

    def self.from_uri(uri)
      config.from_uri(uri)
    end

    def self.read(*args, **opts)
      config.read(*args, **opts)
    end

    def self.read(*args, **opts)
      config.read(*args, **opts) { |document| yield document }
    end

    def read(path : String)
      source = yield YAML.parse(File.read(path))
      from_yaml(source)
    end

    def read(path : String, env : String | Symbol = :development)
      _env = env.to_s
      read(path) { |document| document[_env] }
    end

    def from_yaml(source)
      {% for field in STRING_FIELDS %}
        @{{field.id}} = source["{{field.id}}"].as_s if source["{{field.id}}"]?
      {% end %}
      {% for field in INT_FIELDS %}
        @{{field.id}} = source["{{field.id}}"].as_s.to_i if source["{{field.id}}"]?
      {% end %}
      {% for field in FLOAT_FIELDS %}
        @{{field.id}} = source["{{field.id}}"].as_s.to_f if source["{{field.id}}"]?
      {% end %}
      self.local_time_zone_name = source["local_time_zone_name"].as_s if source["local_time_zone_name"]?

      {% for field in BOOL_FIELDS %}
        @{{field.id}} = source["{{field.id}}"].as_s == "true" if source["{{field.id}}"]?
      {% end %}
      validate_config
      self
    end

    def from_uri(uri : String)
      from_uri(URI.parse(uri))
    rescue e
      logger.error("Error parsing database uri #{uri}")
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
          {%
            method =
              if STRING_FIELDS.includes?(field)
                "to_s"
              elsif INT_FIELDS.includes?(field)
                "to_i"
              else
                "to_f"
              end
          %}
          @{{field.id}} = params["{{field.id}}"].{{method.id}} if params["{{field.id}}"]?
        {% end %}
      end
      validate_config
      self
    end
  end
end
