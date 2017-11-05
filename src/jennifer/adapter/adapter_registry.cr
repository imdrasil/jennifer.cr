module Jennifer
  module Adapter
    class AdapterRegistry

      @@adapter_classes = {} of String => Base.class

      @@adapter_instances = {} of Symbol => Jennifer::Adapter::Base

      # Register an adapter class with a given name.
      #
      def self.register_adapter(name : String, adapter_class : Jennifer::Adapter::Base.class)
        @@adapter_classes[name] = adapter_class
      end


      register_adapter("postgres", Jennifer::Adapter::Postgres)
      # register_adapter("mysql", Jennifer::Adapter::Mysql)
      # register_adapter(:sqlite3, Jennifer::Adapter::Sqlite.class)

      # Retrieve the adapter class registered with a given name
      # Raises UnknownAdapter error if no adapter has been regiestered with that name
      #
      def self.adapter_class(name : String)
        raise UnknownAdapter.new(name, @@adapter_classes.keys) unless @@adapter_classes.has_key?(name)
        return @@adapter_classes[name]
      end

      # Create/Retrieve an Adapter instance for a given config key
      # if no config key is supplied then :default is assumed. the first time this
      # is invoked, the adapter is created and this instance
      #
      def self.adapter(config_key : Symbol = :default)
        unless @@adapter_instances.has_key?(config_key)
          config = Config.get_instance(config_key)
          config.logger.debug("Creating instance of '#{config.adapter}' adapter using '#{config_key}' config")
          adapter_class = adapter_class(config.adapter)
          adapter = adapter_class.not_nil!.build(config_key)
          @@adapter_instances[config_key] = adapter
          adapter.prepare
        end
        @@adapter_instances[config_key].not_nil!
      end
    end
  end
end
