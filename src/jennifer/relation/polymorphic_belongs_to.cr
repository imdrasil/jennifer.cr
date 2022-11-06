module Jennifer
  module Relation
    abstract class IPolymorphicBelongsTo < IRelation
      DEFAULT_PRIMARY_FIELD = "id"

      getter foreign : String, primary : String, name : String, foreign_type : String

      def initialize(@name, foreign : String | Symbol?, primary : String | Symbol?, foreign_type : String | Symbol?)
        @foreign_type = foreign_type ? foreign_type.to_s : "#{name}_type"
        @foreign = foreign ? foreign.to_s : Wordsmith::Inflector.foreign_key(name)
        @primary = primary ? primary.to_s : DEFAULT_PRIMARY_FIELD
      end

      private abstract def related_model(arg : String)
      private abstract def table_name(type : String)

      def condition_clause(ids : Array(DBAny), polymorphic_type : String?)
        model = related_model(polymorphic_type)
        model.c(primary_field, @name).in(ids)
      end

      def condition_clause(id : DBAny, polymorphic_type : String?)
        model = related_model(polymorphic_type)
        model.c(primary_field, @name) == id
      end

      def query(id, polymorphic_type : Nil)
        Query.null
      end

      def query(id, polymorphic_type : String)
        condition = condition_clause(id, polymorphic_type)
        Query[table_name(polymorphic_type)].where { condition }
      end

      def foreign_field
        @foreign
      end

      def primary_field
        @primary
      end

      def insert(obj : Model::Base, rel : Hash)
        unless rel.has_key?(foreign_type)
          raise ::Jennifer::BaseException.new("Given hash has no #{foreign_type} field.")
        end

        type_field = rel[foreign_type].as(String)
        main_obj = create!(rel, type_field)
        obj.update_columns({
          foreign_field => main_obj.attribute_before_typecast(primary_field),
          foreign_type  => type_field,
        })
        main_obj
      end

      def insert(obj : Model::Base, rel : Model::Base)
        unless obj.attribute(foreign_field).nil?
          raise ::Jennifer::BaseException.new("Object already belongs to another object")
        end

        obj.update_columns({
          foreign_field => rel.attribute(primary_field),
          foreign_type  => rel.class.to_s,
        })
        rel.save! if rel.new_record?
        rel
      end

      def remove(obj : Model::Base)
        obj.update_columns({foreign_field => nil, foreign_type => nil})
      end

      def build(opts : Hash, polymorphic_type)
        related_model(polymorphic_type).new(opts, false)
      end

      private def related_model(arg : Model::Base)
        related_model(arg.attribute_before_typecast(foreign_type).as(String))
      end

      private def table_name(type : String)
        related_model(type).table_name
      end

      macro define_relation_class(name, klass, related_class, types, request)
        # :nodoc:
        class {{name.id.camelcase}}Relation < ::Jennifer::Relation::IPolymorphicBelongsTo
          private def related_model(arg : String)
            case arg
            {% for type in types %}
            when {{type}}.to_s
              {{type}}
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown polymorphic type #{arg}")
            end
          end

          {% if request %}
            def query(id, polymorphic_type : String)
              condition = condition_clause(id, polymorphic_type)
              Query[table_name(polymorphic_type)].where { condition }.exec {{request}}
            end
          {% end %}

          def create!(opts : Hash, polymorphic_type)
            case polymorphic_type
            {% for type in types %}
            when {{type}}.to_s
              {{type}}.create!(opts)
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown polymorphic type #{polymorphic_type}")
            end
          end

          def load(foreign_field, polymorphic_type : String?)
            return if foreign_field.nil? || polymorphic_type.nil?
            condition = condition_clause(foreign_field, polymorphic_type)
            case polymorphic_type
            {% for type in types %}
            when {{type}}.to_s
              {{type}}.where { condition }.first
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown polymorphic type #{polymorphic_type}")
            end
          end

          # Destroys related to *obj* object. Is called on `dependent: :destroy`.
          def destroy(obj : {{klass}})
            foreign_field = obj.attribute_before_typecast(foreign)
            polymorphic_type = obj.attribute_before_typecast(foreign_type).as(String?)
            return if foreign_field.nil? || polymorphic_type.nil?

            condition = condition_clause(foreign_field, polymorphic_type)
            case polymorphic_type
            {% for type in types %}
            when {{type}}.to_s
              {{type}}.where { condition }.destroy
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown polymorphic type #{polymorphic_type}")
            end
          end
        end
      end

      def table_name
        raise AbstractMethod.new("table_name", self)
      end

      def model_class
        raise AbstractMethod.new("model_class", self)
      end

      def join_query
        raise AbstractMethod.new("join_query", self)
      end

      def query(primary_value_or_array)
        raise AbstractMethod.new("query", self)
      end

      def join_condition(query, type)
        raise ::Jennifer::BaseException.new("Polymorphic belongs_to relation can't be dynamically joined.")
      end

      def preload_relation(collection, out_collection : Array(::Jennifer::Model::Resource), pk_repo)
        raise ::Jennifer::BaseException.new("Polymorphic belongs_to relation can't be preloaded.")
      end
    end
  end
end
