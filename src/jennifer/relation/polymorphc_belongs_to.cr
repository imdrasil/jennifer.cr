module Jennifer
  module Relation
    abstract class IPolymorphicBelongsTo < IRelation
      getter foreign : String, primary : String
      getter name : String, type_field : String

      def initialize(@name, foreign : String | Symbol?, foreign_type : String | Symbol?, primary : String | Symbol?)
        @type_field = foreign_type ? foreign_type.to_s : "#{name}_type"
        @foreign = foreign ? foreign.to_s : "#{name}_id"
        @primary = primary ? primary.to_s : "id"
      end

      abstract def related_model(arg)
      abstract def table_name(type)

      def condition_clause(id, polymorphic_type : String?)
        model = related_model(polymorphic_type)
        _tree = model.c(primary_field) == id
        _tree
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

      macro define_relation_class(name, klass, related_class, types)
        class {{name.id.camelcase}}Relation < ::Jennifer::Relation::IPolymorphicBelongsTo
          def initialize(*opts)
            super
          end

          def related_model(obj : {{klass}})
            related_model(obj.attribute(type_field))
          end

          def related_model(type : String)
            case type
            {% for type in types %}
            when {{type.stringify}}
              {{type}}
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown polymorphic type #{type}")
            end
          end

          def table_name(type : String)
            case type
            {% for type in types %}
            when {{type.stringify}}
              {{type}}.table_name
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown polymorphic type #{type}")
            end
          end

          def build(opts : Hash, polymorphic_type)
            case polymorphic_type
            {% for type in types %}
            when {{type.stringify}}
              {{type}}.build(opts, false)
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown polymorphic type #{polymorphic_type}")
            end
          end

          def create!(opts : Hash, polymorphic_type)
            case polymorphic_type
            {% for type in types %}
            when {{type.stringify}}
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
            when {{type.stringify}}
              {{type}}.where { condition }.first
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown polymorphic type #{polymorphic_type}")
            end
          end

          def destroy(obj : {{klass}})
            foreign_field = obj.attribute(foreign)
            polymorphic_type = obj.attribute(type_field).as(String?)
            return if foreign_field.nil? || polymorphic_type.nil?

            condition = condition_clause(foreign_field, polymorphic_type)
            case polymorphic_type
            {% for type in types %}
            when {{type.stringify}}
              {{type}}.where { condition }.destroy
            {% end %}
            else
              raise ::Jennifer::BaseException.new("Unknown polymorphic type #{polymorphic_type}")
            end
          end

          def insert(obj : {{klass}}, rel : Hash(String, Jennifer::DBAny))
            foreign_type = rel[type_field].as(String)
            main_obj = create!(rel, foreign_type)
            obj.update_columns({ foreign_field => main_obj.attribute(primary_field), type_field => foreign_type })
            main_obj
          end

          def insert(obj : {{klass}}, rel : {{related_class}})
            raise ::Jennifer::BaseException.new("Object already belongs to another object") unless obj.attribute(foreign_field).nil?
            obj.update_columns({ foreign_field => rel.attribute(primary_field), type_field => rel.class.to_s })
            rel.save! if rel.new_record?
            rel
          end

          def remove(obj : {{klass}})
            obj.update_columns({ foreign_field => nil, type_field => nil })
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

      def query(a)
        raise AbstractMethod.new("query", self)
      end

      def condition_clause
        raise AbstractMethod.new("condition_clause", self)
      end

      def condition_clause(id)
        raise AbstractMethod.new("condition_clause", self)
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
