require "../query_builder/query"

module Jennifer
  module Model
    abstract class Base
      extend Support
      include Support

      TYPES = {
        Integer  => Int32,
        Int32    => Int32,
        String   => String,
        SmallInt => Int16,
        Bool     => Bool,
        Serial   => Int64,
        Int64    => Int64,
      }

      alias Supportable = Int32 | String | Float32 | Bool | Base

      macro mapping(properties)
        @@field_names = [
          {% for key, v in properties %}
            "{{key.id}}",
          {% end %}
        ]

        def self.field_count
          {{properties.size}}
        end

        def self.field_names
          @@field_names
        end

        # generating hash with options
        {% for key, value in properties %}
          class Jennifer::QueryBuilder::Query(T)
            def {{key}}
              c("{{key.id}}")
            end
          end

          {% unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
            {% properties[key] = {type: TYPES[value], aliased_type: value} %}
          {% else %}
            {% properties[key][:aliased_type] = properties[key][:type] %}
            {% properties[key][:type] = TYPES[properties[key][:type]] %}
          {% end %}
          {% if properties[key][:primary] %}
            {% primary = key %}
            {% primary_type = properties[key][:type] %}
          {% end %}
        {% end %}

        # creates getter and setters
        {% for key, value in properties %}
          {% t_string = properties[key][:type].stringify %}
          {% properties[key][:parsed_type] = properties[key][:null] || properties[key][:primary] ? t_string + "?" : t_string %}
          @{{key.id}} : {{value[:parsed_type].id}}

          {% if value[:setter] == nil ? true : value[:setter] %}
            def {{key.id}}=(_{{key.id}} : {{value[:parsed_type].id}})
              @{{key.id}} = _{{key.id}}
            end
          {% end %}

          {% if value[:getter] == nil ? true : value[:getter] %}
            def {{key.id}}
              @{{key.id}}
            end
          {% end %}

          def self._{{key}}
            c("{{key.id}}")
          end

          {% if value[:primary] %}
            def primary
              @{{key.id}}
            end

            def self.primary
              c("{{key.id}}")
            end

            def self.primary_field_name
              "{{key.id}}"
            end

            def self.primary_field_type
              {{value[:type]}}
            end

            {% if primary && Int32.stringify == primary_type.stringify %}
              def init_primary_field(value : {{value[:type]}})
                raise "Primary field is already initialized" if @{{key.id}}
                @{{key.id}} = value
              end
            {% end %}
          {% end %}
        {% end %}

        @new_record = true

        # creates object from db tuple
        def initialize(%pull : DB::ResultSet)
          @new_record = false
          {% for key, value in properties %}
            %var{key.id} = nil
            %found{key.id} = false
          {% end %}

          {{properties.size}}.times do |i|
            column = %pull.column_name(%pull.column_index)
            case column
            {% for key, value in properties %}
              when {{value[:column_name] || key.id.stringify}}
                %found{key.id} = true
                %var{key.id} = %pull.read({{value[:parsed_type].id}})
            {% end %}
            else
              raise "Unknown column #{column}"
            end
          end

          {% for key, value in properties %}
            @{{key.id}} = %var{key.id}.as({{value[:parsed_type].id}})
          {% end %}
        end

        def initialize(values : Hash | NamedTuple)
          {% for key, value in properties %}
            %var{key.id} = nil
            %found{key.id} = true
          {% end %}

          {% for key, value in properties %}
            if !values[:{{key.id}}]?.nil?
              %var{key.id} = values[:{{key.id}}]
            elsif !values["{{key.id}}"]?.nil?
              %var{key.id} = values["{{key.id}}"]
            else
              %found{key.id} = false
            end
          {% end %}


          {% for key, value in properties %}
            {% if value[:null] %}
              {% if value[:default] != nil %}
                @{{key.id}} = %found{key.id} ? %var{key.id}.as({{value[:parsed_type].id}}) : {{value[:default]}}
              {% else %}
                @{{key.id}} = %var{key.id}.as({{value[:parsed_type].id}})
              {% end %}
            {% elsif value[:default] != nil %}
              @{{key.id}} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : %var{key.id}.as({{value[:parsed_type].id}})
            {% else %}
              @{{key.id}} = (%var{key.id}).as({{value[:parsed_type].id}})
            {% end %}
          {% end %}
        end

        def initialize(values : Hash | NamedTuple, @new_record)
          initialize(values)
        end

        #def attributes=(values : Hash)
        # {% for key, value in properties %}
        #    if !values[:{{key.id}}]?.nil?
        #      %var{key.id} = values[:{{key.id}}]
        #    elsif !values["{{key.id}}"]?.nil?
        #      %var{key.id} = values["{{key.id}}"]
        #    else
        #      %found{key.id} = false
        #    end
        #  {% end %}
        #end

        def initialize(**values)
          initialize(values)
        end

        def initialize
          initialize({} of Symbol => DB::Any)
        end

        def new_record?
          @new_record
        end

        def self.create(values : Hash | NamedTuple)
          o = new(values)
          o.save
          o
        end

        def self.create
          a = {} of Symbol => Supportable
          o = new(a)
          o.save
          o
        end

        def self.create(**values)
          o = new(values.to_h)
          o.save
          o
        end

        def save
          if new_record?
            res = ::Jennifer::Adapter.adapter.insert(self)
            {% if primary && (Int32.stringify == primary_type.stringify) %}
              unless primary
                init_primary_field(res.last_insert_id.to_i)
              end
            {% end %}
            @new_record = false
            res
          else
            ::Jennifer::Adapter.adapter.update(self)
          end
        end

        def to_h
          {
            {% for key, value in properties %}
              :{{key.id}} => @{{key.id}},
            {% end %}
          }
        end

        def attribute(name : String)
          case name
          {% for key, value in properties %}
          when "{{key.id}}"
            @{{key.id}}
          {% end %}
          else
            raise "Unknown model attribute - #{name}"
          end
        end

        def attribute(name : Symbol)
          attribute(name.to_s)
        end

        def attributes_hash
          hash = to_h
          {% for key, value in properties %}
            {% if !value[:null] || value[:primary] %}
              hash.delete(:{{key}}) if hash[:{{key}}]?.nil?
            {% end %}
          {% end %}
          hash
        end
      end

      macro mapping(**properties)
        mapping({{properties}})
      end

      @@table_name : String | Nil

      def self.table_name(value : String | Symbol)
        @@table_name = value.to_s
      end

      def self.table_name : String
        @@table_name ||= pluralize(self.to_s.underscore)
      end

      def self.c(name)
        ::Jennifer::QueryBuilder::Criteria.new(name, table_name)
      end

      abstract def primary

      macro scope(name, opts, block = nil)
        def self.{{name.id}}({% if block %} {{ opts.map(&.stringify).map { |e| "_" + e[1..-1] }.join(", ").id }} {% end %})
          {% if block %}
            {{ opts.map(&.stringify).map { |e| e[1..-1] }.join(", ").id }} = {{opts.map(&.stringify).map { |e| "_" + e[1..-1] }.join(", ").id}}
          {% end %}
          where {{block ? block : opts}}
        end
      end

      macro has_many(name, klass, request = nil, foreign = nil, primary = nil)
        @@relations["{{name.id}}"] =
          ::Jennifer::Model::Relation({{klass}}, {{@type}}).new("{{name.id}}", :has_many, {{foreign}}, {{primary}},
            ::Jennifer::QueryBuilder::Query({{klass}}).new{% if request %}.where {{request}} {% end %})

        {% RELATION_NAMES << "#{name.id}" %}

        @{{name.id}} = [] of {{klass}}

        def {{name.id}}_query
          primary_field =
            {% if primary %}
              {{primary.id}}
            {% else %}
              primary
            {% end %}
          @@relations["{{name.id}}"].condition_clause(primary_field)
        end

        def {{name.id}}
          @{{name.id}} ||= {{name.id}}_query.to_a.as(Array({{klass}}))
        end

        def set_{{name.id}}(rel : Hash)
          @{{name.id}} << {{klass}}.new(rel)
        end

        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.to_a
        end
      end

      macro belongs_to(name, klass, request = nil, foreign = nil, primary = nil)
        @@relations["{{name.id}}"] =
          ::Jennifer::Model::Relation({{klass}}, {{@type}}).new("{{name.id}}", :belongs_to, {{foreign}}, {{primary}},
            ::Jennifer::QueryBuilder::Query({{klass}}).new{% if request %}.where {{request}} {% end %})
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

        def {{name.id}}_reload
          foreign_field =
            {% if foreign %}
              "{{foreign.id}}"
            {% else %}
              singularize({{klass}}.table_name) + "_id"
            {% end %}

          @{{name.id}} = @@relations["{{name.id}}"].condition_clause(attribute(foreign_field)).first.as({{klass}} | Nil)
        end

        def set_{{name.id}}(rel : Hash)
          @{{name.id}} = {{klass}}.new(rel)
        end
      end

      macro has_one(name, klass, request = nil, foreign = nil, primary = nil)
        @@relations["{{name.id}}"] =
          ::Jennifer::Model::Relation({{klass}}, {{@type}}).new("{{name.id}}", :has_one, {{foreign}}, {{primary}},
            ::Jennifer::QueryBuilder::Query({{klass}}).new{% if request %}.where {{request}} {% end %})
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

        def {{name.id}}_reload
          primary_field =
            {% if primary %}
              {{primary.id}}
            {% else %}
              primary
            {% end %}

          @{{name.id}} = @@relations["{{name.id}}"].condition_clause(primary_field).first.as({{klass}} | Nil)
        end

        def set_{{name.id}}(rel : Hash)
          @{{name.id}} = {{klass}}.new(rel)
        end
      end

      macro inherited
        RELATION_NAMES = [] of String
        @@relations = {} of String => ::Jennifer::Model::IRelation

        def self.relations
          @@relations
        end

        def self.relation(name : String)
          @@relations[name]
        rescue e : KeyError
          raise Jennifer::UnknownRelation.new(self.to_s, /"(?<r>.*)"$/.match(e.message.to_s).try &.["r"])
        end

        macro finished
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
        delete
      end

      def delete
        return if new_record?
        this = self
        self.class.where { this.class.primary == this.primary }.delete
      end

      def self.where(&block)
        ac = all
        tree = with ac yield
        ac.set_tree(tree)
        ac
      end

      def self.all
        QueryBuilder::Query(self).new(table_name)
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
        destroy(*ids)
      end

      def self.delete_all
        destroy_all
      end

      def self.search_by_sql(query : String, args = [] of Supportable)
      end
    end
  end
end
