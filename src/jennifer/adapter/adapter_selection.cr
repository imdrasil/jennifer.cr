module Jennifer
  module Adapter
    module AdapterSelection

      # macro to redefine the adapter method to have it use a specific named
      # configuration.
      macro using_config(config_name)
        def self.adapter
          Jennifer::Adapter::AdapterRegistry.adapter({{config_name}})
        end
      end

    end
  end
end
