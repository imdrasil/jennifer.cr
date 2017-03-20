require "./adapter/base"

module Jennifer
  module Adapter
    @@adapter : Base?
    @@adapters = {} of String => Base.class

    def self.adapter
      @@adapter ||= adapter_class.not_nil!.new
    end

    def self.adapter_class
      adapters[Config.adapter]
    end

    def self.t(value)
      adapter_class.t(value)
    end

    def self.arg_replacement(rhs : Array(Bool | Float32 | Int32 | Jennifer::QueryBuilder::Criteria | String))
      adapter_class.arg_replacement(rhs)
    end

    def self.escape_string(size = 1)
      adapter_class.escape_string(size)
    end

    def self.adapters
      @@adapters
    end

    def self.register_adapter(name, adapter)
      adapters[name] = adapter
    end
  end
end
