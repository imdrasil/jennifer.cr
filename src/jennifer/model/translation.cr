module Jennifer
  module Model
    # Includes localization methods.
    #
    # Depends of parent class `.lookup_ancestors` and `.i18n_scope` methods.
    module Translation
      module ClassMethods
        # Search translation for given attribute name.
        def human_attribute_name(name : String | Symbol)
          prefix = "#{GLOBAL_SCOPE}.attributes."

          lookup_ancestors do |ancestor|
            path = "#{prefix}#{ancestor.i18n_key}.#{name}"
            return I18n.translate(path) if I18n.exists?(path)
          end

          path = "#{prefix}.#{name}"
          return I18n.translate(path) if I18n.exists?(path)
          Wordsmith::Inflector.humanize(name)
        end

        # Returns localized model name.
        def human(count = nil)
          prefix = "#{GLOBAL_SCOPE}.#{i18n_scope}."

          lookup_ancestors do |ancestor|
            path = prefix + ancestor.i18n_key
            return I18n.translate(path, count: count) if I18n.exists?(path, count: count)
          end

          name = Wordsmith::Inflector.humanize(i18n_key)
          name = Wordsmith::Inflector.pluralize(name) if count && count > 1
          name
        end

        # Returns the i18n scope for the class.
        def i18n_scope
          :models
        end

        # Presents key which be used to search any related to current class localization information.
        def i18n_key
          return @@i18n_key unless @@i18n_key.empty?
          @@i18n_key = Wordsmith::Inflector.underscore(Wordsmith::Inflector.demodulize(to_s)).downcase
        end

        # Yields all ancestors until `Base`.
        def lookup_ancestors(&)
          klass = self
          while klass
            yield klass
            klass = klass.superclass
          end
        end
      end

      # All possible types to be used for localization.
      alias LocalizeableTypes = Int32 | Int64 | Nil | Float32 | Float64 | Time | String | Symbol | Bool

      # Default global translation scope.
      GLOBAL_SCOPE = "jennifer"

      # Delegates the call to `self.class`.
      def lookup_ancestors(&)
        self.class.lookup_ancestors { |ancestor| yield ancestor }
      end

      # Delegates the call to `self.class`.
      def human_attribute_name(name : String | Symbol)
        self.class.human_attribute_name(name)
      end

      def class_name : String
        self.class.to_s.underscore.gsub(/::/, "_")
      end

      macro included
        @@i18n_key : String = ""

        extend ::Jennifer::Model::Translation::ClassMethods
      end
    end
  end
end

I18n.load_path << File.join(__DIR__, "../locale")
