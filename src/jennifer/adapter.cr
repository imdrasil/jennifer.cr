require "./adapter/base"

module Jennifer
  alias AnyResult = DB::Any | Int8 | Int16 | JSON::Any
  alias AnyArgument = AnyResult | Array(AnyResult)

  module Adapter
    @@adapter : Base?
    @@adapters = {} of String => Base.class
    @@adapter_class : Base.class | Nil

    {% for method in [:exec, :scalar] %}
      def self.{{method.id}}(*opts)
        adapter.{{method.id}}(*opts)
      end
    {% end %}

    def self.query(_query, args = [] of DB::Any)
      adapter.query(_query, args) { |rs| yield rs }
    end

    # :nodoc:
    # Allows to assign newly created adapter and call setupe methods with existing adapter
    private def self.adapter=(_adapter)
      @@adapter = _adapter
    end

    def self.adapter
      @@adapter ||= begin
        a = adapter_class.not_nil!.build
        self.adapter = a
        a.prepare
        a
      end
    end

    def self.adapter_class
      @@adapter_class ||= adapters[Config.adapter]
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
