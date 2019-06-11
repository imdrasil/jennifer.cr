module Jennifer::Model
  # :nodoc:
  module CommonMapping
    # :nodoc:
    macro common_mapping(strict)
      {%
        primary = COLUMNS_METADATA.keys.find { |field| COLUMNS_METADATA[field][:primary] }
        primary_auto_incrementable = primary && AUTOINCREMENTABLE_STR_TYPES.includes?(COLUMNS_METADATA[primary][:type].stringify)
        properties = COLUMNS_METADATA
        nonvirtual_attrs = properties.keys.select { |attr| !properties[attr][:virtual] }
        raise "Model #{@type} has no defined primary field. For now model without primary field is not allowed" if primary == nil
      %}

      __field_declaration({{properties}}, {{primary_auto_incrementable}})

      # :nodoc:
      def self.field_count
        {{properties.size}}
      end

      # :nodoc:
      FIELD_NAMES = [{{properties.keys.map { |e| "#{e.id.stringify}" }.join(", ").id}}]

      # :nodoc:
      def self.field_names
        FIELD_NAMES
      end

      # :nodoc:
      def self.columns_tuple
        COLUMNS_METADATA
      end

      @[JSON::Field(ignore: true)]
      @new_record = true
      @[JSON::Field(ignore: true)]
      @destroyed = false

      # Creates object from `DB::ResultSet`
      def initialize(%pull : DB::ResultSet)
        @new_record = false
        {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(%pull)
      end

      # :nodoc:
      def self.new(pull : DB::ResultSet)
        {% verbatim do %}
        {% begin %}
          {% klasses = @type.all_subclasses.select { |s| s.constant("STI") == true } %}
          {% if !klasses.empty? %}
            hash = adapter.result_to_hash(pull)
            case hash["type"]
            when "", nil, "{{@type}}"
              new(hash, false)
            {% for klass in klasses %}
            when "{{klass}}"
              {{klass}}.new(hash, false)
            {% end %}
            else
              raise ::Jennifer::UnknownSTIType.new(self, hash["type"])
            end
          {% else %}
            instance = allocate
            instance.initialize(pull)
            instance.__after_initialize_callback
            instance
          {% end %}
        {% end %}
        {% end %}
      end

      # Accepts symbol hash or named tuple, stringify it and calls constructor with string-based keys hash.
      def initialize(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
        initialize(Ifrit.stringify_hash(values, Jennifer::DBAny))
      end

      # :nodoc:
      def self.new(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
        instance = allocate
        instance.initialize(values)
        instance.__after_initialize_callback
        instance
      end

      def initialize(values : Hash(String, ::Jennifer::DBAny))
        {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
      end

      # :nodoc:
      def self.new(values : Hash(String, ::Jennifer::DBAny))
        instance = allocate
        instance.initialize(values)
        instance.__after_initialize_callback
        instance
      end

      # :nodoc:
      def initialize(values : Hash | NamedTuple, @new_record)
        initialize(values)
      end

      # :nodoc:
      def self.new(values : Hash | NamedTuple, new_record : Bool)
        instance = allocate
        instance.initialize(values, new_record)
        instance.__after_initialize_callback
        instance
      end

      # :nodoc:
      def to_h
        {
          {% for key in nonvirtual_attrs %}
            :{{key.id}} => {{key.id}},
          {% end %}
        } of Symbol => ::Jennifer::DBAny
      end

      # :nodoc:
      def to_str_h
        {
          {% for key in nonvirtual_attrs %}
            {{key.stringify}} => {{key.id}},
          {% end %}
        } of String => ::Jennifer::DBAny
      end

      # :nodoc:
      def attribute(name : String | Symbol, raise_exception : Bool = true)
        case name.to_s
        {% for attr in properties.keys %}
        when "{{attr.id}}"
          @{{attr.id}}
        {% end %}
        else
          raise ::Jennifer::BaseException.new("Unknown model attribute - #{name}") if raise_exception
        end
      end

      private def init_attributes(values : Hash)
        {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
      end

      private def init_attributes(values : DB::ResultSet)
        {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
      end

      private def inspect_attributes(io) : Nil
        io << ' '
        {% for var, i in properties.keys %}
          {% if i > 0 %} io << ", " {% end %}
          io << "{{var.id}}: "
          @{{var.id}}.inspect(io)
        {% end %}
        nil
      end
    end
  end
end
