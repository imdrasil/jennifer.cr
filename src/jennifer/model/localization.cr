module Jennifer
  module Model
    # Includes localization methods.
    #
    # Depends of parent class `::lookup_ancestors` and `::i18n_scope` methods.
    module Localization
      GLOBAL_SCOPE = "jennifer"

      # Search translation for given attribute.
      def human_attribute_name(attribute : String | Symbol)
        prefix = "#{GLOBAL_SCOPE}.attributes."

        tr = try_translate(prefix + "#{i18n_key}.#{attribute}")
        return tr.as(String) if tr
        lookup_ancestors do |ancestor|
          tr = try_translate(prefix + "#{ancestor.i18n_key}.#{attribute}")
          return tr.as(String) if tr
        end

        Inflector.humanize(attribute)
      end

      # Returns localized model name.
      def human
        prefix = "#{GLOBAL_SCOPE}.#{i18n_scope}."

        tr = try_translate(prefix + i18n_key)
        return tr.as(String) if tr
        lookup_ancestors do |ancestor|
          tr = try_translate(prefix + ancestor.i18n_key)
          return tr.as(String) if tr
        end

        Inflector.humanize(i18n_key)
      end

      def i18n_scope
        :models
      end

      # Represents key whcih be used to search any related to current class localization information.
      def i18n_key
        return @@i18n_key unless @@i18n_key.empty?
        @@i18n_key = Inflector.underscore(Inflector.demodulize(to_s)).downcase
      end

      private def lookup_ancestors(&block)
        klass = superclass
        while true
          yield klass
          break if !klass.responds_to?(:superclass)
          klass = klass.superclass
        end
      end

      private def try_translate(path)
        tr = I18n.backend.translations[I18n.default_locale][path]?
        tr ? tr.to_s : tr
      end

      macro extended
        @@i18n_key : String = ""
      end
    end
  end
end
