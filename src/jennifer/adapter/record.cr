module Jennifer
  # General data structure for the raw data retrieved for the DB.
  #
  # Dynamically generates getters using `.method_missing`. If class `T` is passed
  # as an argument - return value is automatically casted to it.
  #
  # ```
  # Jennifer::Query["users"].first.name(String)
  # ```
  struct Record
    getter attributes

    def initialize(@attributes : Hash(String, DBAny))
    end

    def initialize
      @attributes = {} of String => DBAny
    end

    # Returns names of fields.
    def fields
      @attributes.keys
    end

    # Alias for #attribute.
    def [](name : Symbol | String)
      attribute(name)
    end

    # Returns value by attribute *name*.
    def attribute(name : String)
      @attributes[name]
    rescue e : KeyError
      raise BaseException.new("Column '#{name}' is missing")
    end

    # :ditto:
    def attribute(name : Symbol)
      attribute(name.to_s)
    end

    # Returns casted value of attribute *name* to the type *type*.
    def attribute(name : String | Symbol, type : T.class) : T forall T
      value = attribute(name)
      if value.is_a?(T)
        value
      else
        raise BaseException.new("Field \"#{name}\" (#{value.class}) is not of type #{T}.")
      end
    end

    # Returns a string containing a human-readable representation of object.
    def inspect(io) : Nil
      io << "Jennifer::Record("
      @attributes.each_with_index do |(name, value), index|
        io << ", " if index > 0
        io << name << ": "
        value.inspect(io)
      end
      io << ')'
    end

    # Returns a JSON string representing data set.
    #
    # For more details see `Resource#to_json`.
    def to_json(only : Array(String)? = nil, except : Array(String)? = nil, &)
      JSON.build do |json|
        to_json(json, only, except) { yield json, self }
      end
    end

    def to_json(json : JSON::Builder)
      to_json(json) { }
    end

    def to_json(json : JSON::Builder, only : Array(String)? = nil, except : Array(String)? = nil, &)
      json.object do
        field_names =
          if only
            only
          elsif except
            fields - except
          else
            fields
          end
        field_names.each do |name|
          json.field(name, attributes[name])
        end
        yield json, self
      end
    end

    def to_json(only : Array(String)? = nil, except : Array(String)? = nil)
      JSON.build do |json|
        to_json(json, only, except) { }
      end
    end

    macro method_missing(call)
      {% if call.args.size == 0 %}
        def {{call.name.id}}
          attribute({{call.name.id.stringify}})
        end
      {% elsif call.args.size == 1 %}
        def {{call.name.id}}(type : T.class) : T forall T
          attribute({{call.name.stringify}}, T)
        end
      {% end %}
    end
  end
end
