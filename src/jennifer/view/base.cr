require "./experimental_mapping"

module Jennifer
  module View
    abstract class Base
      extend Ifrit
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

      # NOTE: for query generating
      def self.table_name
        view_name
      end

      def self.view_name(value : String)
        @@view_name = value
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

      def append_relation(name : String, hash)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      def relation_retrieved(name : String)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      abstract def attribute(name)

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
          FIELDS.size
        end

        macro finished
          def __after_initialize_callback
            \{% for method in AFTER_INITIALIZE_CALLBACKS %}
              \{{method.id}}
            \{% end %}
          rescue ::Jennifer::Skip
          end
        end
      end

      macro def self.views
        {% begin %}
          {% if @type.all_subclasses.size > 0 %}
            [
              {% for view in @type.all_subclasses %}
                {{view.id}},
              {% end %}
            ]
          {% else %}
            [] of Jennifer::View::Base.class
          {% end %}
        {% end %}
      end
    end
  end
end
