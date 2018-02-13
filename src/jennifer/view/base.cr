require "./experimental_mapping"

module Jennifer
  module View
    abstract class Base
      extend Ifrit
      extend Model::Translation
      include ExperimentalMapping
      include Model::Scoping

      macro after_initialize(*names)
        {% for name in names %}
          {% AFTER_INITIALIZE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      def self.view_name
        @@view_name ||= to_s.underscore.pluralize
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

      def self.build(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
        o = new(values)
        o.__after_initialize_callback
        o
      end

      def self.build(values : Hash(String, ::Jennifer::DBAny))
        o = new(values)
        o.__after_initialize_callback
        o
      end

      def self.build(values : Hash | NamedTuple, new_record : Bool)
        build(values)
      end

      def self.all
        QueryBuilder::ModelQuery(self).new(table_name)
      end

      def self.where(&block)
        ac = all
        tree = with ac.expression_builder yield
        ac.set_tree(tree)
        ac
      end

      def self.c(name)
        ::Jennifer::QueryBuilder::Criteria.new(name, table_name)
      end

      def self.c(name : String, relation)
        ::Jennifer::QueryBuilder::Criteria.new(name, table_name, relation)
      end

      def self.adapter
        Adapter.adapter
      end

      def self.i18n_scope
        :views
      end

      def append_relation(name : String, hash)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      def relation_retrieved(name : String)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      def __after_initialize_callback
        true
      end

      abstract def attribute(name)

      def self.views
        {% begin %}
          {% if @type.all_subclasses.size > 1 %}
            [{{@type.all_subclasses.join(", ").id}}] - [Jennifer::View::Materialized]
          {% else %}
            [] of Jennifer::View::Base.class
          {% end %}
        {% end %}
      end

      macro inherited
        AFTER_INITIALIZE_CALLBACKS = [] of String

        # NOTE: stub for query builder
        @@relations = {} of String => ::Jennifer::Relation::IRelation
        def self.relations
          @@relations
        end

        def self.relation(name : String)
          @@relations[name]
        rescue e : KeyError
          raise Jennifer::UnknownRelation.new(self, e)
        end

        # NOTE: override regular behavior - used fields count instead of
        # quering db
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
