module Jennifer::Model
  # :nodoc:
  module CommonMapping
    # :nodoc:
    macro common_mapping(strict)
      {%
        primary = COLUMNS_METADATA.keys.find { |field| COLUMNS_METADATA[field][:primary] }
        primary_auto_incrementable = false
        if primary
          primary_options = COLUMNS_METADATA[primary]
          primary_auto_incrementable = AUTOINCREMENTABLE_STR_TYPES.any? { |type| primary_options[:parsed_type].includes?(type) }
        end
        properties = COLUMNS_METADATA
        nonvirtual_attrs = properties.keys.select { |attr| !properties[attr][:virtual] }
      %}

      __field_declaration({{properties}}, {{primary_auto_incrementable}})

      # :nodoc:
      def self.field_count : Int32
        {{properties.size}}
      end

      # :nodoc:
      FIELD_NAMES = [{{properties.keys.map { |e| "#{e.id.stringify}" }.join(", ").id}}]

      # :nodoc:
      def self.field_names : Array(String)
        [{{properties.keys.map { |e| "#{e.id.stringify}" }.join(", ").id}}]
      end

      def self.column_names : Array(String)
        [{{properties.keys.select { |attr| !properties[attr][:virtual] }.map { |e| "#{e.id.stringify}" }.join(", ").id}}]
      end

      # :nodoc:
      def self.columns_tuple
        COLUMNS_METADATA
      end

      # Creates object from `DB::ResultSet`
      def initialize(%pull : DB::ResultSet)
        @new_record = false
        {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(%pull)
      end

      # :nodoc:
      def self.new(values : DB::ResultSet)
        {% verbatim do %}
        {% begin %}
          {% klasses = @type.all_subclasses.select { |klass| klass.constant("STI") == true } %}
          {% if !klasses.empty? %}
            hash = adapter.result_to_hash(values)
            case hash["type"]
            when "", nil, "{{@type}}"
              instance = allocate
              instance.initialize(hash, false)
              instance.__after_initialize_callback
              instance
            {% for klass in klasses %}
            when "{{klass}}"
              {{klass}}.new(hash, false)
            {% end %}
            else
              raise ::Jennifer::UnknownSTIType.new(self, hash["type"])
            end
          {% else %}
            instance = allocate
            instance.initialize(values)
            instance.__after_initialize_callback
            instance
          {% end %}
        {% end %}
        {% end %}
      end

      # Accepts symbol hash or named tuple, stringify it and calls constructor with string-based keys hash.
      def initialize(values : Hash(Symbol, AttrType) | NamedTuple, @new_record)
        initialize(Ifrit.stringify_hash(values, AttrType), @new_record)
      end

      # :nodoc:
      def self.new(values : Hash(Symbol, AttrType) | NamedTuple, new_record = true)
        {% verbatim do %}
        {% begin %}
          {% klasses = @type.all_subclasses.select { |klass| klass.constant("STI") == true } %}
          {% if !klasses.empty? %}
            case values[:type]?
            when "", nil, "{{@type}}"
              instance = allocate
              instance.initialize(values, new_record)
              instance.__after_initialize_callback
              instance
            {% for klass in klasses %}
            when "{{klass}}"
              {{klass}}.new(values, new_record)
            {% end %}
            else
              raise ::Jennifer::UnknownSTIType.new(self, values[:type])
            end
          {% else %}
            instance = allocate
            instance.initialize(values, new_record)
            instance.__after_initialize_callback
            instance
          {% end %}
        {% end %}
        {% end %}
      end

      def initialize(values : Hash(String, AttrType), @new_record)
        {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
      end

      # :nodoc:
      def self.new(values : Hash(String, AttrType), new_record = true)
        {% verbatim do %}
        {% begin %}
          {% klasses = @type.all_subclasses.select { |klass| klass.constant("STI") == true } %}
          {% if !klasses.empty? %}
            case values["type"]?
            when "", nil, "{{@type}}"
              instance = allocate
              instance.initialize(values, new_record)
              instance.__after_initialize_callback
              instance
            {% for klass in klasses %}
            when "{{klass}}"
              {{klass}}.new(values, new_record)
            {% end %}
            else
              raise ::Jennifer::UnknownSTIType.new(self, values["type"])
            end
          {% else %}
            instance = allocate
            instance.initialize(values, new_record)
            instance.__after_initialize_callback
            instance
          {% end %}
        {% end %}
        {% end %}
      end

      # :nodoc:
      def to_h
        {
          {% for key in nonvirtual_attrs %}
            :{{key.id}} => {{key.id}},
          {% end %}
        } of Symbol => AttrType
      end

      # :nodoc:
      def to_str_h
        {
          {% for key in nonvirtual_attrs %}
            {{key.stringify}} => {{key.id}},
          {% end %}
        } of String => AttrType
      end

      # :nodoc:
      def attribute(name : String | Symbol, raise_exception : Bool = true)
        case name.to_s
        {% for attr in properties.keys %}
        when "{{attr.id}}"
          self.{{attr.id}}
        {% end %}
        else
          raise ::Jennifer::UnknownAttribute.new(name, self.class) if raise_exception
        end
      end

      # :nodoc:
      def attribute_before_typecast(name : String | Symbol) : ::Jennifer::DBAny
        case name.to_s
        {% for attr, options in properties %}
        when "{{attr.id}}"
          {% if options[:converter] %}
            {{options[:converter]}}.to_db(self.{{attr.id}}, self.class.columns_tuple[:{{attr.id}}])
          {% else %}
            self.{{attr.id}}
          {% end %}
        {% end %}
        else
          raise ::Jennifer::UnknownAttribute.new(name, self.class)
        end
      end

      private def init_attributes(values : Hash)
        {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
      end

      private def init_attributes(values : DB::ResultSet)
        {{properties.keys.map { |key| "@#{key.id}" }.join(", ").id}} = _extract_attributes(values)
      end
    end
  end
end
