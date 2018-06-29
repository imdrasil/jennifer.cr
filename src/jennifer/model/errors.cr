module Jennifer
  module Model
    class Errors
      getter base : Base
      getter messages : Hash(Symbol, Array(String))

      def initialize(@base)
        @messages = Hash(Symbol, Array(String)).new { |hash, key| hash[key] = [] of String }
      end

      def_clone

      protected def initialize_copy(other)
        @messages = other.@messages.dup
        @base = other.@base
      end

      # Returns `true` if the error messages include an error for the given key
      # `attribute`, `false` otherwise.
      def include?(attribute : Symbol)
        messages.has_key?(attribute) && messages[attribute].present?
      end

      # Clear the error messages.
      def clear
        @messages.clear
      end

      # Delete messages for `key`. Returns the deleted messages.
      def delete(key : Symbol)
        messages.delete(key)
      end

      # When passed a symbol or a name of a method, returns an array of errors
      # for the method.
      def [](attribute : Symbol)
        messages[attribute]
      end

      def []?(attribute : Symbol)
        messages[attribute]?
      end

      # Iterates through each error key, value pair in the error messages hash.
      # Yields the attribute and the error for that attribute. If the attribute
      # has more than one error message, yields once for each error message.
      def each
        messages.each_key do |attribute|
          messages[attribute].each { |error| yield attribute, error }
        end
      end

      # Returns the number of error messages.
      def size
        values.flatten.size
      end

      # Returns all message values.
      def values
        errors = [] of String
        messages.each do |attr, array|
          errors += array unless array.empty?
        end
        errors
      end

      # Returns all message keys.
      def keys
        attrs = [] of Symbol
        messages.each do |key, value|
          attrs << key unless value.empty?
        end
        attrs
      end

      # Returns `true` if no errors are found, `false` otherwise.
      # If the error message is a string it can be empty.
      def empty?
        size == 0
      end

      def any?
        !empty?
      end

      def blank?
        empty?
      end

      # Adds `message` to the error messages and used validator type to `details` on `attribute`.
      # More than one error can be added to the same `attribute`.
      # If no `message` is supplied, `:invalid` is assumed.
      def add(attribute : Symbol, message : String | Symbol = :invalid, count : Int? = nil, options : Hash = {} of String => String)
        messages[attribute] << generate_message(attribute, message, count, options)
      end

      def add(attribute : Symbol, message : String | Symbol = :invalid, options : Hash = {} of String => String)
        add(attribute, message, nil, options)
      end

      # Returns all the full error messages in an array.
      def full_messages
        errors = [] of String
        each { |attribute, message| errors << full_message(attribute, message) }
        errors
      end

      def to_a
        full_messages
      end

      # Returns all the full error messages for a given attribute in an array.
      def full_messages_for(attribute : Symbol)
        messages[attribute].map { |message| full_message(attribute, message) }
      end

      # Returns a full message for a given attribute.
      def full_message(attribute : Symbol, message : String)
        return message if attribute == :base
        attr_name = @base.class.human_attribute_name(attribute)
        I18n.translate("#{Translation::GLOBAL_SCOPE}.errors.format", default: "#{attribute} #{message}", options: { "attribute" => attr_name, "message" => message })
      end

      # Translates an error message in its default scope
      def generate_message(attribute : Symbol, message : Symbol, count, options : Hash)
        prefix = "#{Translation::GLOBAL_SCOPE}.errors."
        opts = { count: count, options: options}

        @base.class.lookup_ancestors do |ancestor|
          path = "#{prefix}#{ancestor.i18n_key}.attributes.#{attribute}.#{message}"
          return I18n.translate(path, **opts) if I18n.exists?(path, count: count)
          path = "#{prefix}#{ancestor.i18n_key}.#{message}"
          return I18n.translate(path, **opts) if I18n.exists?(path, count: count)
        end

        path = "#{prefix}#{attribute}.#{message}"
        return I18n.translate(path, **opts) if I18n.exists?(path, count: count)
        path = "#{prefix}messages.#{message}"
        return I18n.translate(path, **opts) if I18n.exists?(path, count: count)

        Inflector.humanize(message).downcase
      end

      def generate_message(attribute : Symbol, message : String, count, options : Hash)
        message
      end

      def inspect(io) : Nil
        io << "#<" << {{@type.name.id.stringify}} << ":0x"
        object_id.to_s(16, io)
          io << " @messages="
          @messages.inspect(io)
        io << '>'
        nil
      end
    end
  end
end
