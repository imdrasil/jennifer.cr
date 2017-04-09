require "./mapping"
require "./validation"

module Jennifer
  module Model
    abstract class Base
      include Support
      include Mapping
      include Validation

      alias Supportable = DBAny | Base

      @@table_name : String?
      @@singular_table_name : String?

      def self.table_name(value : String | Symbol)
        @@table_name = value.to_s
      end

      def self.singular_table_name(value : String | Symbol)
        @@singular_table_name = value.to_s
      end

      def self.c(name)
        ::Jennifer::QueryBuilder::Criteria.new(name, table_name)
      end

      def self.c(name, relation)
        ::Jennifer::QueryBuilder::Criteria.new(name, table_name, relation)
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

      def self.build(values : Hash | NamedTuple, new_record)
        o = new(values, new_record)
        o.__after_initialize_callback
        o
      end

      def self.build(**values)
        o = new(values)
        o.__after_initialize_callback
        o
      end

      def self.build
        o = new
        o.__after_initialize_callback
        o
      end

      abstract def primary

      macro scope(name, opts, block = nil)
        class Jennifer::QueryBuilder::Query(T)
          def {{name.id}}({% if block %} *args{% end %})
            T.{{name.id}}(self{% if block %}, *args {% end %})
          end
        end

        def self.{{name.id}}({% if block %} {{ opts.map(&.stringify).map { |e| "__" + e }.join(", ").id }} {% end %})
          {% if block %}
            {{ opts.map(&.stringify).join(", ").id }} = {{opts.map(&.stringify).map { |e| "__" + e }.join(", ").id}}
          {% end %}
          all.exec {{block ? block : opts}}
        end

        def self.{{name.id}}(_query : ::Jennifer::QueryBuilder::Query({{@type}}){% if block %}, {{ opts.map(&.stringify).map { |e| "__" + e }.join(", ").id }} {% end %})
          {% if block %}
            {{ opts.map(&.stringify).join(", ").id }} = {{opts.map(&.stringify).map { |e| "__" + e }.join(", ").id}}
          {% end %}
          _query.exec {{block ? block : opts}}
        end
      end

      macro has_many(name, klass, request = nil, foreign = nil, primary = nil)
        @@relations["{{name.id}}"] =
          ::Jennifer::Model::Relation({{klass}}, {{@type}}).new("{{name.id}}", :has_many, {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %})

        {% RELATION_NAMES << "#{name.id}" %}

        @{{name.id}} = [] of {{klass}}

        def {{name.id}}_query
          primary_field =
            {% if primary %}
              {{primary.id}}
            {% else %}
              primary
            {% end %}
          condition = @@relations["{{name.id}}"].condition_clause(primary_field)
          {{klass}}.where { condition }
        end

        def {{name.id}}
          @{{name.id}} = {{name.id}}_query.to_a.as(Array({{klass}})) if @{{name.id}}.empty?
          @{{name.id}}
        end

        def set_{{name.id}}(rel : Hash)
          @{{name.id}} << {{klass}}.build(rel)
        end

        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.to_a.as(Array({{klass}}))
        end
      end

      macro belongs_to(name, klass, request = nil, foreign = nil, primary = nil)
        @@relations["{{name.id}}"] =
          ::Jennifer::Model::Relation({{klass}}, {{@type}}).new("{{name.id}}", :belongs_to, {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %})
        {% RELATION_NAMES << "#{name.id}" %}
        @{{name.id}} : {{klass}}?

        def {{name.id}}
          if @{{name.id}}
            @{{name.id}}
          else
            {{name.id}}_reload
          end
        end

        def {{name.id}}!
          {{name.id}}.not_nil!
        end

        def {{name.id}}_query
          foreign_field =
            {% if foreign %}
              "{{foreign.id}}"
            {% else %}
              {{klass}}.singular_table_name + "_id"
            {% end %}
          condition = @@relations["{{name.id}}"].condition_clause(attribute(foreign_field))
          {{klass}}.where { condition }
        end

        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.first
        end

        def set_{{name.id}}(rel : Hash)
          @{{name.id}} = {{klass}}.build(rel)
        end
      end

      macro has_one(name, klass, request = nil, foreign = nil, primary = nil)
        @@relations["{{name.id}}"] =
          ::Jennifer::Model::Relation({{klass}}, {{@type}}).new("{{name.id}}", :has_one, {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %})
        {% RELATION_NAMES << "#{name.id}" %}

        @{{name.id}} : {{klass}}?

        def {{name.id}}
          if @{{name.id}}
            @{{name.id}}
          else
            {{name.id}}_reload
          end
        end

        def {{name.id}}!
          {{name.id}}.not_nil!
        end

        def {{name.id}}_query
          primary_field =
            {% if primary %}
              {{primary.id}}
            {% else %}
              primary
            {% end %}

          condition = @@relations["{{name.id}}"].condition_clause(primary_field)
          {{klass}}.where { condition }
        end

        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.first
        end

        def set_{{name.id}}(rel : Hash)
          @{{name.id}} = {{klass}}.build(rel)
        end
      end

      macro before_save(*names)
        {% for name in names %}
          {% BEFORE_SAVE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro after_save(*names)
        {% for name in names %}
          {% AFTER_SAVE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro before_create(*names)
        {% for name in names %}
          {% BEFORE_CREATE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro after_create(*names)
        {% for name in names %}
          {% AFTER_CREATE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro after_initialize(*names)
        {% for name in names %}
          {% AFTER_INITIALIZE_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro before_destroy(*names)
        {% for name in names %}
          {% BEFORE_DESTROY_CALLBACKS << name.id.stringify %}
        {% end %}
      end

      macro inherited
        ::Jennifer::Model::Validation.inherited_hook

        RELATION_NAMES = [] of String

        BEFORE_SAVE_CALLBACKS = [] of String
        AFTER_SAVE_CALLBACKS = [] of String
        BEFORE_CREATE_CALLBACKS = [] of String
        AFTER_CREATE_CALLBACKS = [] of String
        AFTER_INITIALIZE_CALLBACKS = [] of String
        BEFORE_DESTROY_CALLBACKS = [] of String

        @@relations = {} of String => ::Jennifer::Model::IRelation

        after_save :__refresh_changes

        def self.table_name : String
          @@table_name ||= {{@type}}.to_s.underscore.pluralize
        end

        def self.singular_table_name
          @@singular_table_name ||= {{@type}}.to_s.underscore
        end

        def self.relations
          @@relations
        end

        def self.relation(name : String)
          @@relations[name]
        rescue e : KeyError
          raise Jennifer::UnknownRelation.new(self, /"(?<r>.*)"$/.match(e.message.to_s).try &.["r"])
        end

        def self.superclass
          {{@type.superclass}}
        end

        macro finished
          ::Jennifer::Model::Validation.finished_hook

          def __before_save_callback
            \{% for method in BEFORE_SAVE_CALLBACKS %}
              \{{method.id}}
            \{% end %}
          end

          def __after_save_callback
            \{% for method in AFTER_SAVE_CALLBACKS %}
              \{{method.id}}
            \{% end %}
          end

          def __before_create_callback
            \{% for method in BEFORE_CREATE_CALLBACKS %}
              \{{method.id}}
            \{% end %}
          end

          def __after_create_callback
            \{% for method in AFTER_CREATE_CALLBACKS %}
              \{{method.id}}
            \{% end %}
          end

          def __after_initialize_callback
            \{% for method in AFTER_INITIALIZE_CALLBACKS %}
              \{{method.id}}
            \{% end %}
          end

          def __before_destroy_callback
            \{% for method in BEFORE_DESTROY_CALLBACKS %}
              \{{method.id}}
            \{% end %}
          end

          def set_relation(name, hash)
            \{% if RELATION_NAMES.size > 0 %}
              case name
              \{% for rel in RELATION_NAMES %}
                when \{{rel}}
                  set_\{{rel.id}}(hash)
              \{% end %}
              else
                raise Jennifer::UnknownRelation.new({{@type}}, name)
              end
            \{% end %}
          end
        end
      end

      def destroy
        return if new_record?
        __before_destroy_callback
        delete
      end

      def delete
        return if new_record?
        this = self
        self.class.where { this.class.primary == this.primary }.delete
      end

      def self.where(&block)
        ac = all
        tree = with ac.expression_builder yield
        ac.set_tree(tree)
        ac
      end

      def self.find(id)
        _id = id
        this = self
        where { this.primary == _id }.first
      end

      def self.find!(id)
        _id = id
        this = self
        where { this.primary == _id }.first!
      end

      def self.all
        QueryBuilder::Query(self).build(table_name)
      end

      def self.destroy(*ids)
        _ids = ids
        where do
          if _ids.size == 1
            c(primary_field_name) == _ids[0]
          else
            c(primary_field_name).in(_ids)
          end
        end.destroy
      end

      def self.destroy_all
        all.destroy
      end

      def self.delete(*ids)
        _ids = ids
        where do
          if _ids.size == 1
            c(primary_field_name) == _ids[0]
          else
            c(primary_field_name).in(_ids)
          end
        end.delete
      end

      def self.delete_all
        destroy_all
      end

      def self.search_by_sql(query : String, args = [] of Supportable)
        result = [] of self
        ::Jennifer::Adapter.adapter.query(query, args) do |rs|
          rs.each do
            result << build(rs)
          end
        end
        result
      end
    end
  end
end
