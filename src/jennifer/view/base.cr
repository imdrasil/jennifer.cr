require "./experimental_mapping"

module Jennifer
  module View
    abstract class Base < Model::Resource
      include ExperimentalMapping

      macro after_initialize(*names)
        {% for name in names %}
          {% AFTER_INITIALIZE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      def self.view_name
        @@view_name ||= Inflector.pluralize(to_s.underscore)
      end

      def self.view_name(value : String)
        @@view_name = value
      end

      # NOTE: is used for query generating
      def self.table_name
        view_name
      end

      def self.build(pull : DB::ResultSet)
        o = new(pull)
        o.__after_initialize_callback
        o
      end

      def self.build(values : Hash | NamedTuple, new_record : Bool)
        build(values)
      end

      def self.i18n_scope
        :views
      end

      def self.views
        {% begin %}
          {% if @type.all_subclasses.size > 1 %}
            [{{@type.all_subclasses.join(", ").id}}] - [Jennifer::View::Materialized]
          {% else %}
            [] of Jennifer::View::Base.class
          {% end %}
        {% end %}
      end

      def __after_initialize_callback
        true
      end

      def self.relation(name)
        raise Jennifer::UnknownRelation.new(self, KeyError.new(name))
      end

      macro inherited
        AFTER_INITIALIZE_CALLBACKS = [] of String
        RELATIONS = {} of String => ::Jennifer::Relation::IRelation

        def self.relation(name : String)
          RELATIONS[name]
        rescue e : KeyError
          super(name)
        end

        # NOTE: override regular behavior - used fields count instead of
        # querying db
        def self.actual_table_field_count
          COLUMNS_METADATA.size
        end

        def self.superclass
          {{@type.superclass}}
        end

        macro finished
          def __after_initialize_callback
            return false unless super
            \{{AFTER_INITIALIZE_CALLBACKS.join("\n").id}}
            true
          rescue ::Jennifer::Skip
            false
          end
        end
      end
    end
  end
end

require "./materialized"
