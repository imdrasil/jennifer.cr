module Jennifer
  struct Record
    getter attributes

    def initialize(@attributes : Hash(String, DBAny))
    end

    def initialize(result_set : DB::ResultSet)
      @attributes = Adapter.adapter.result_to_hash(result_set)
    end

    def initialize
      @attributes = {} of String => DBAny
    end

    def fields
      @attributes.keys
    end

    def [](name : Symbol)
      self[name.to_s]
    end

    def [](name : String)
      @attributes[name]
    end

    def attribute(value)
      self[value]
    end

    macro method_missing(call)
      {% if call.args.size == 0 %}
        def {{call.name.id}}
          @attributes[{{call.name.id.stringify}}]
        end
      {% elsif call.args.size == 1 %}
        def {{call.name.id}}(type : T.class) : T forall T
          value = {{call.name.id}}
          if value.is_a?(T)
            value
          else
            raise BaseException.new("Field {{call.name.id}} is not of type #{T}.")
          end
        end
      {% end %}
    end
  end
end
