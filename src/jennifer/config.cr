module Jennifer
  # Configuration container.
  #
  # At the moment it implements singleton pattern but can be scaled to support several
  # configuration instances per application.
  #
  # All class methods with same names as instance ones delegates the calls to default configuration (global)
  # object.
  #
  # Supported configurations:
  #
  # * `migration_files_path = "./db/migrations"`
  # * `verbose_migrations = true`
  # * `model_files_path = "./src/models"`
  # * `structure_folder` parent folder of `migration_files_path`
  # * `host = "localhost"`
  # * `port = -1`
  # * `schema = "public"`
  # * `user`
  # * `password`
  # * `db`
  # * `adapter`
  # * `pool_size = 1`
  # * `retry_attempts = 1`
  # * `checkout_timeout = 5.0`
  # * `retry_delay = 1.0`
  # * `auth_methods = ""`
  # * `sslmode = ""`
  # * `sslcert = ""`
  # * `sslkey = ""`
  # * `sslrootcert = ""`
  # * `local_time_zone_name` default time zone name
  # * `skip_dumping_schema_sql = false`
  # * `command_shell = "bash"`
  # * `docker_container = ""`
  # * `docker_source_location = ""`
  # * `command_shell_sudo = false`
  # * `migration_failure_handler_method = :none`
  # * `allow_outdated_pending_migration = false`
  # * `max_bind_vars_count = nil`
  # * `time_zone_aware_attributes = true`
  #
  # ```
  # Jennifer::Config.configure do |conf|
  #   conf.host = "localhost"
  #   conf.user = "root"
  #   conf.password = ""
  #   conf.adapter = "mysql"
  #   conf.db = "crystal"
  # end
  # ```
  class Config
    # Supported migration execution failure strategies.
    #
    # * `MigrationFailureHandler::ReverseDirection` - will invoke an opposite method
    # (`#down` for up-migration and vice versa)
    # * `MigrationFailureHandler::Callback` - will invoke `#after_up_failure` or `#after_down_failure` method
    # * `MigrationFailureHandler::None` - do nothing
    enum MigrationFailureHandler
      ReverseDirection
      Callback
      None
    end

    # Context name used for logger.
    LOG_CONTEXT = "db"

    # :nodoc:
    CONNECTION_URI_PARAMS = {
      :max_pool_size, :initial_pool_size, :max_idle_pool_size,
      :retry_attempts, :checkout_timeout, :retry_delay,
      :auth_methods, :sslmode, :sslcert, :sslkey, :sslrootcert,
    }
    # :nodoc:
    STRING_FIELDS = {
      :user, :password, :db, :host, :adapter, :migration_files_path, :schema,
      :structure_folder, :local_time_zone_name, :command_shell, :docker_container, :docker_source_location,
      :model_files_path, :auth_methods, :sslmode, :sslcert, :sslkey, :sslrootcert,
    }
    # :nodoc:
    INT_FIELDS = {:port, :max_pool_size, :initial_pool_size, :max_idle_pool_size, :retry_attempts}
    # :nodoc:
    FLOAT_FIELDS = {:checkout_timeout, :retry_delay}
    # :nodoc:
    BOOL_FIELDS = {
      :command_shell_sudo,
      :skip_dumping_schema_sql,
      :verbose_migrations,
      :allow_outdated_pending_migration,
      :time_zone_aware_attributes,
    }
    # :nodoc:
    ALLOWED_MIGRATION_FAILURE_HANDLER_METHODS = %w(reverse_direction callback none)

    # :nodoc:
    macro define_fields(const, default)
      {% for field in const.resolve %}
        property {{field.id}} = {{default}}
        delegate_property {{field.id}}
      {% end %}
    end

    # :nodoc:
    macro delegate_property(*methods)
      {% for method in methods %}
        # Delegates to `#{{method}}`.
        def self.{{method.id}}
          instance.{{method.id}}
        end
      {% end %}

      {% for method in methods %}
        # Delegates to `#{{method}}=`.
        def self.{{method.id}}=(value)
          instance.{{method.id}}= value
        end
      {% end %}
    end

    define_fields(STRING_FIELDS, "")
    define_fields(INT_FIELDS, 0)
    define_fields(FLOAT_FIELDS, 0.0)
    define_fields(BOOL_FIELDS, false)

    # Returns whether migrations should be performed in verbose mode.
    #
    # Default is `true`.
    getter verbose_migrations = true

    # Handler type for the failed migrations; default is `"none"`.
    getter migration_failure_handler_method

    # Defines postgres database schema name (postgres specific configuration).
    getter schema = "public"

    # Returns local time zone.
    getter local_time_zone : Time::Location

    # Maximum count of bind variables.
    #
    # If `nil` - uses default adapter value.
    property max_bind_vars_count : Int32?

    # `Log` instance.
    #
    # Default is `Log.for("db")`
    getter logger : Log

    # Whether Jennifer should convert time objects to UTC and back to application time zone when store/load them
    # from a database.
    #
    # If set to `false` all time objects will be treated as local time - `Time#to_local_in` will be used instead of `Time#in`.
    getter time_zone_aware_attributes = true

    @@instance = new

    def initialize
      @adapter = ""
      @host = "localhost"
      @port = -1
      @migration_files_path = "./db/migrations"
      @model_files_path = "./src/models"
      @local_time_zone = Time::Location.local
      @local_time_zone_name = @local_time_zone.name

      @initial_pool_size = 1
      @max_pool_size = 1
      @max_idle_pool_size = 1

      @retry_attempts = 1

      @checkout_timeout = 5.0
      @retry_delay = 1.0

      @auth_methods = ""
      @sslmode = ""
      @sslcert = ""
      @sslkey = ""
      @sslrootcert = ""

      @command_shell = "bash"
      @migration_failure_handler_method = MigrationFailureHandler::None
      @logger = Log.for(LOG_CONTEXT)

      @max_bind_vars_count = nil
    end

    @[Deprecated("Use Log.setup(\"db\", severity) instead of assigning custom logger")]
    def logger=(value)
      @logger = value
    end

    # Sets `max_pool_size`, `max_idle_pool_size` and `initial_pool_size` to the given *value*.
    def pool_size=(value : Int32)
      self.max_pool_size = self.max_idle_pool_size = self.initial_pool_size = value
    end

    # Default configuration object used by application.
    def self.instance : self
      @@instance
    end

    # Returns default configuration object.
    def self.configure : self
      instance
    end

    # :ditto:
    def self.config : self
      instance
    end

    # Yields default configuration instance to block and validates it.
    def self.configure(&)
      yield instance
      instance.validate_config
    end

    # Delegates call to #from_uri.
    def self.from_uri(uri)
      config.from_uri(uri)
    end

    # Delegates call to #read.
    def self.read(*args, **opts)
      instance.read(*args, **opts)
    end

    def self.read(*args, **opts, &)
      instance.read(*args, **opts) { |document| yield document }
    end

    # Returns maximum size of the pool.
    def pool_size
      max_pool_size
    end

    # Returns `schema.sql` folder name.
    def structure_folder : String
      if @structure_folder.empty?
        File.dirname(@migration_files_path)
      else
        @structure_folder
      end
    end

    # Return path to `structure.sql` file.
    def structure_path : String
      File.join(structure_folder, "structure.sql")
    end

    # Delegates call to #structure_path.
    def self.structure_path : String
      instance.structure_path
    end

    # Reinitialize new configuration object with default values
    def self.reset_config : Config
      @@instance = new
    end

    delegate_property(:logger, :max_bind_vars_count)

    def local_time_zone_name=(value : String)
      @local_time_zone_name = value
      @local_time_zone = Time::Location.load(value)
      value
    end

    # Delegates call to #local_time_zone.
    def self.local_time_zone
      instance.local_time_zone
    end

    def migration_failure_handler_method=(value : MigrationFailureHandler)
      @migration_failure_handler_method = value
    end

    # Reads configurations from the file with given *path* for given *env*.
    #
    # All configuration properties will be read from the *env* key.
    #
    # ```
    # Jennifer::Config.read("./db/database.yml", :production)
    # ```
    def read(path : String, env : Symbol = :development)
      read(path, env.to_s)
    end

    # :ditto:
    def read(path : String, env : String)
      read(path) { |document| document[env] }
    end

    # Reads configurations from the file with given *path*.
    #
    # It is considered that all configuration properties are located at the root level.
    def read(path : String, &)
      source = yield YAML.parse(File.read(path))
      from_yaml(source)
    end

    # Reads configuration properties from the given YAML *source*.
    def from_yaml(source)
      casted_source = source.as_h
      {% for field in STRING_FIELDS %}
        @{{field.id}} = string_from_yaml(source, "{{field.id}}") if casted_source.has_key?("{{field.id}}")
      {% end %}
      {% for field in INT_FIELDS %}
        @{{field.id}} = int_from_yaml(source, "{{field.id}}") if casted_source.has_key?("{{field.id}}")
      {% end %}
      {% for field in FLOAT_FIELDS %}
        @{{field.id}} = float_from_yaml(source, "{{field.id}}") if casted_source.has_key?("{{field.id}}")
      {% end %}
      {% for field in BOOL_FIELDS %}
        @{{field.id}} = bool_from_yaml(source, "{{field.id}}") if casted_source.has_key?("{{field.id}}")
      {% end %}

      if casted_source.has_key?("migration_failure_handler_method")
        self.migration_failure_handler_method =
          MigrationFailureHandler.parse(string_from_yaml(source, "migration_failure_handler_method"))
      end

      self.local_time_zone_name = source["local_time_zone_name"].as_s if casted_source.has_key?("local_time_zone_name")
      self.pool_size = int_from_yaml(source, "pool_size") if casted_source.has_key?("pool_size")
      if casted_source.has_key?("max_bind_vars_count")
        self.max_bind_vars_count = int_from_yaml(source, "max_bind_vars_count")
      end

      validate_config
      self
    end

    # Reads configuration properties from the given *uri* string.
    #
    # ```
    # Jennifer::Config.from_uri("mysql://root:password@somehost:3306/some_database")
    # ```
    def from_uri(uri : String)
      from_uri(URI.parse(uri))
    rescue e
      logger.error { "Error parsing database uri #{uri}" }
    end

    # Reads configuration properties from the given *uri*.
    def from_uri(uri : URI)
      @adapter = uri.scheme.to_s if uri.scheme
      @host = uri.host.to_s if uri.host
      @port = uri.port.not_nil! if uri.port
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
        self.pool_size = params["pool_size"].to_i if params["pool_size"]?
      end
      validate_config
      self
    end

    protected def validate_config
      raise Jennifer::InvalidConfig.bad_adapter if adapter.empty?
      raise Jennifer::InvalidConfig.bad_database if db.empty?
      return if max_idle_pool_size == max_pool_size && max_pool_size == initial_pool_size

      logger.warn do
        "It is highly recommended to set max_idle_pool_size = max_pool_size = initial_pool_size to prevent " \
        "blowing up count of DB connections. For any details take a look at " \
        "https://github.com/crystal-lang/crystal-db/issues/77"
      end
    end

    private def string_from_yaml(source, field)
      source[field].as_s
    rescue e : TypeCastError
      raise "Invalid property value for #{field}: '#{source[field]}'\n#{e.message}"
    end

    private def int_from_yaml(source, field)
      source[field].as_s.to_i
    rescue e : TypeCastError
      raise "Invalid property value for #{field}: '#{source[field]}'\n#{e.message}"
    end

    private def float_from_yaml(source, field)
      source[field].as_s.to_f
    rescue e : TypeCastError
      raise "Invalid property value for #{field}: '#{source[field]}'\n#{e.message}"
    end

    private def bool_from_yaml(source, field)
      source[field].to_s == "true"
    rescue e : TypeCastError
      raise "Invalid property value for #{field}: '#{source[field]}'\n#{e.message}"
    end
  end
end
