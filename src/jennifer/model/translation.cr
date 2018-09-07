module Jennifer
  module Model
    # Includes localization methods.
    #
    # Depends of parent class `::lookup_ancestors` and `::i18n_scope` methods.
    module Translation
      alias LocalizeableTypes = Int32 | Int64 | Nil | Float32 | Float64 | Time | String | Symbol | Bool

      GLOBAL_SCOPE = "jennifer"

      # Search translation for given attribute.
      def human_attribute_name(attribute : String | Symbol)
        prefix = "#{GLOBAL_SCOPE}.attributes."

        lookup_ancestors do |ancestor|
          path = "#{prefix}#{ancestor.i18n_key}.#{attribute}"
          return I18n.translate(path) if I18n.exists?(path)
        end

        path = "#{prefix}.#{attribute}"
        return I18n.translate(path) if I18n.exists?(path)
        Inflector.humanize(attribute)
      end

      # Returns localized model name.
      def human(count = nil)
        prefix = "#{GLOBAL_SCOPE}.#{i18n_scope}."

        lookup_ancestors do |ancestor|
          path = prefix + ancestor.i18n_key
          return I18n.translate(path, count: count) if I18n.exists?(path, count: count)
        end

        name = Inflector.humanize(i18n_key)
        name = Inflector.pluralize(name) if count && count > 1
        name
      end

      def i18n_scope
        :models
      end

      # Represents key which be used to search any related to current class localization information.
      def i18n_key
        return @@i18n_key unless @@i18n_key.empty?
        @@i18n_key = Inflector.underscore(Inflector.demodulize(to_s)).downcase
      end

      # Yields all ancestors which respond to `.superclass`.
      def lookup_ancestors(&block)
        klass = self
        while klass
          yield klass
          klass = klass.superclass
        end
      end

      macro extended
        @@i18n_key : String = ""
      end
    end
  end
end

I18n.load_path << File.join(__DIR__, "../locale")

# TODO: make a PR to the i18n repo
module I18n
  def self.exists?(key, locale = config.locale, count = nil)
    key += (count == 1 ? ".one" : ".other") if count
    config.backend.translations[locale].has_key?(key)
  end
end
