module Jennifer
  struct Record
    getter attributes

    def initialize(@attributes : Hash(String, DBAny))
    end

    def initialize(result_set : DB::ResultSet)
      # TODO: decouple adapter
      @attributes = Adapter.default_adapter.result_to_hash(result_set)
    end

    def initialize
      @attributes = {} of String => DBAny
    end

    def fields
      @attributes.keys
    end

    def [](name : Symbol | String)
      attribute(name)
    end

    def attribute(name : String)
      @attributes[name]
    end

    def attribute(name : Symbol)
      @attributes[name.to_s]
    end

    def attribute(name : String | Symbol, type : T.class) : T forall T
      value = @attributes[name.to_s]
      if value.is_a?(T)
        value
      else
        raise BaseException.new("Field \"#{name}\" (#{value.class}) is not of type #{T}.")
      end
    end

    macro method_missing(call)
      {% if call.args.size == 0 %}
        def {{call.name.id}}
          @attributes[{{call.name.id.stringify}}]
        end
      {% elsif call.args.size == 1 %}
        def {{call.name.id}}(type : T.class) : T forall T
          attribute({{call.name.stringify}}, T)
        end
      {% end %}
    end
  end
end
