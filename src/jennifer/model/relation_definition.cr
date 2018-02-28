module Jennifer
  module Model
    module RelationDefinition
      def __refresh_relation_retrieves
      end

      abstract def set_inverse_of(name : String, object)
      abstract def append_relation(name : String, hash)
      abstract def relation_retrieved(name : String)
      abstract def get_relation(name : String)

      macro nullify_dependency(name, relation_type)
        def __nullify_callback_{{name.id}}
          rel = \{{@type}}.relation({{name.id.stringify}})
          {{name.id}}_query.update({rel.foreign_field => nil})
        end

        before_destroy :__nullify_callback_{{name.id}}
      end

      macro delete_dependency(name, relation_type)
        def __delete_callback_{{name.id}}
          rel = \{{@type}}.relation({{name.id.stringify}})
          {{name.id}}_query.delete
        end

        before_destroy :__delete_callback_{{name.id}}
      end

      macro destroy_dependency(name, relation_type)
        def __destroy_callback_{{name.id}}
          rel = \{{@type}}.relation({{name.id.stringify}})
          {{name.id}}_query.destroy
        end

        before_destroy :__destroy_callback_{{name.id}}
      end

      macro restrict_with_exception_dependency(name, relation_type)
        def __restrict_with_exception_callback_{{name.id}}
          rel = \{{@type}}.relation({{name.id.stringify}})
          raise ::Jennifer::RecordExists.new(self, {{name.id.stringify}}) if {{name.id}}_query.exists?
        end

        before_destroy :__restrict_with_exception_callback_{{name.id}}
      end

      macro declare_dependent(name, type, relation_type)
        {% type = type.id.stringify %}
        {% if relation_type == :belongs_to && type == "nullify" %}
          {% raise "Relation \"#{name}\" can't has belongs_to relation with dependent nullify" %}
        {% end %}
        {% if type == "nullify" %}
          ::Jennifer::Model::RelationDefinition.nullify_dependency({{name}}, {{relation_type}})
        {% elsif type == "delete" %}
          ::Jennifer::Model::RelationDefinition.delete_dependency({{name}}, {{relation_type}})
        {% elsif type == "destroy" %}
          ::Jennifer::Model::RelationDefinition.destroy_dependency({{name}}, {{relation_type}})
        {% elsif type == "restrict_with_exception" %}\
          ::Jennifer::Model::RelationDefinition.restrict_with_exception_dependency({{name}}, {{relation_type}})
        {% elsif type == "none" %}
        {% else %}
          {% raise "Dependency type #{type} for relation #{name} of #{@type} is not allowed." %}
        {% end %}
      end

      macro has_many(name, klass, request = nil, foreign = nil, primary = nil, dependent = :nullify, inverse_of = nil)
        {% inverse_of_str = inverse_of.id.stringify %}

        ::Jennifer::Model::RelationDefinition.declare_dependent({{name}}, {{dependent}}, :has_many)

        @@relations["{{name.id}}"] =
          ::Jennifer::Relation::HasMany({{klass}}, {{@type}}).new("{{name.id}}", {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %})

        {{"{% RELATION_NAMES << #{name.id.stringify} %}".id}}

        @{{name.id}} = [] of {{klass}}
        @__{{name.id}}_retrieved = false

        # :nodoc:
        private def set_{{name.id}}_relation(object : Array)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = object
          {% if inverse_of %}
            object.each(&.set_inverse_of({{inverse_of_str}}, self))
          {% end %}
        end

        # :nodoc:
        private def set_{{name.id}}_relation(object)
          @__{{name.id}}_retrieved = true
          @{{name.id}} << object
          {% if inverse_of %}
            object.set_inverse_of({{inverse_of_str}}, self)
          {% end %}
        end

        # returns relation metaobject
        def self.{{name.id}}_relation
          @@relations["{{name.id}}"].as(::Jennifer::Relation::HasMany({{klass}}, {{@type}}))
        end

        # returns relation query for the object
        def {{name.id}}_query
          primary_value = {{ primary ? primary.id : "primary".id }}
          {{@type}}.relation({{name.id.stringify}}).query(primary_value).as(::Jennifer::QueryBuilder::ModelQuery({{klass}}))
        end

        # returns array of related objects
        def {{name.id}}
          if !@__{{name.id}}_retrieved && @{{name.id}}.empty? && !new_record?
            set_{{name.id}}_relation({{name.id}}_query.to_a.as(Array({{klass}})))
          end
          @{{name.id}}
        end

        # builds related object from hash and adds to relation
        def append_{{name.id}}(rel : Hash)
          obj = {{klass}}.build(rel, false)
          set_{{name.id}}_relation(obj)
          obj
        end

        def append_{{name.id}}(rel : {{klass}})
          set_{{name.id}}_relation(rel)
          rel
        end

        def append_{{name.id}}(rel : Jennifer::Model::Resource)
          obj = rel.as({{klass}})
          set_{{name.id}}_relation(obj)
          obj
        end

        def __{{name.id}}_retrieved
          @__{{name.id}}_retrieved = true
        end

        # removes given object from relation array
        def remove_{{name.id}}(rel : {{klass}})
          index = @{{name.id}}.index { |e| e.primary == rel.primary }
          if index
            {{@type}}.{{name.id}}_relation.remove(self, rel)
            @{{name.id}}.delete_at(index)
          end
          rel
        end

        # Insert given object to db and relation; doesn't support `inverse_of` option
        def add_{{name.id}}(rel : Hash)
          @{{name.id}} << {{@type}}.{{name.id}}_relation.insert(self, rel).as({{klass}})
        end

        def add_{{name.id}}(rel : {{klass}})
          @{{name.id}} << {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.to_a.as(Array({{klass}}))
        end
      end

      macro has_and_belongs_to_many(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, association_foreign = nil)
        @@relations["{{name.id}}"] =
          ::Jennifer::Relation::ManyToMany({{klass}}, {{@type}}).new("{{name.id}}", {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %}, {{join_table}}, {{association_foreign}})

        {{"{% RELATION_NAMES << #{name.id.stringify} %}".id}}

        before_destroy :__{{name.id}}_clean

        # Cleans up all join table records for given relation
        def __{{name.id}}_clean
          relation = self.class.{{name.id}}_relation
          this = self
          self.class.adapter.delete(::Jennifer::QueryBuilder::Query.new(relation.join_table!).where do
            c(relation.foreign_field) == this.attribute(relation.primary_field)
          end)
        end

        @{{name.id}} = [] of {{klass}}
        @__{{name.id}}_retrieved = false

        # :nodoc:
        private def set_{{name.id}}_relation(object : Array)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = object
        end

        # :nodoc:
        private def set_{{name.id}}_relation(object)
          @__{{name.id}}_retrieved = true
          @{{name.id}} << object
        end

        def self.{{name.id}}_relation
          @@relations["{{name.id}}"].as(::Jennifer::Relation::ManyToMany({{klass}}, {{@type}}))
        end

        def {{name.id}}_query
          primary_field =
            {% if primary %}
              {{primary.id}}
            {% else %}
              primary
            {% end %}
          @@relations["{{name.id}}"].query(primary_field).as(::Jennifer::QueryBuilder::ModelQuery({{klass}}))
        end

        def {{name.id}}
          if !@__{{name.id}}_retrieved && @{{name.id}}.empty? && !new_record?
            set_{{name.id}}_relation({{name.id}}_query.to_a.as(Array({{klass}})))
          end
          @{{name.id}}
        end

        def append_{{name.id}}(rel : Hash)
          obj = {{klass}}.build(rel, false)
          set_{{name.id}}_relation(obj)
          obj
        end

        def append_{{name.id}}(rel : {{klass}})
          set_{{name.id}}_relation(rel)
          rel
        end

        def append_{{name.id}}(rel : Jennifer::Model::Resource)
          set_{{name.id}}_relation(rel.as({{klass}}))
          rel
        end

        def __{{name.id}}_retrieved
          @__{{name.id}}_retrieved = true
        end

        def remove_{{name.id}}(rel : {{klass}})
          index = @{{name.id}}.index { |e| e.primary == rel.primary }
          if index
            {{@type}}.{{name.id}}_relation.remove(self, rel)
            @{{name.id}}.delete_at(index)
          end
          rel
        end

        # ... ; doesn't support `inverse_of` option
        def add_{{name.id}}(rel : Hash)
          @{{name.id}} << {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        def add_{{name.id}}(rel : {{klass}})
          @{{name.id}} << {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.to_a.as(Array({{klass}}))
        end
      end

      macro belongs_to(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, join_foreign = nil, dependent = :none)
        ::Jennifer::Model::RelationDefinition.declare_dependent({{name}}, {{dependent}}, :belongs_to)

        @@relations["{{name.id}}"] =
          ::Jennifer::Relation::BelongsTo({{klass}}, {{@type}}).new("{{name.id}}", {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %})

        {{"{% RELATION_NAMES << #{name.id.stringify} %}".id}}

        @{{name.id}} : {{klass}}?
        @__{{name.id}}_retrieved = false

        def self.{{name.id}}_relation
          @@relations["{{name.id}}"].as(::Jennifer::Relation::BelongsTo({{klass}}, {{@type}}))
        end

        def {{name.id}}
          if !@__{{name.id}}_retrieved && @{{name.id}}.nil? && !new_record?
            @__{{name.id}}_retrieved = true
            @{{name.id}} = {{name.id}}_reload
          end
          @{{name.id}}
        end

        def {{name.id}}!
          {{name.id}}.not_nil!
        end

        def {{name.id}}_query
          foreign_field = {{ (foreign ? foreign : "attribute(#{klass}.foreign_key_name)").id }}
          @@relations["{{name.id}}"].query(foreign_field).as(::Jennifer::QueryBuilder::ModelQuery({{klass}}))
        end

        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.first.as({{klass}}?)
        end

        def append_{{name.id}}(rel : Hash)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = {{klass}}.build(rel, false)
        end

        def append_{{name.id}}(rel : {{klass}})
          @__{{name.id}}_retrieved = true
          @{{name.id}} = rel
        end

        def append_{{name.id}}(rel : Jennifer::Model::Resource)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = rel.as({{klass}})
        end

        def __{{name.id}}_retrieved
          @__{{name.id}}_retrieved = true
        end

        def remove_{{name.id}}
          {{@type}}.{{name.id}}_relation.remove(self)
          @{{name.id}} = nil
        end

        def add_{{name.id}}(rel : Hash)
          @{{name.id}} = {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        def add_{{name.id}}(rel : {{klass}})
          @{{name.id}} = {{@type}}.{{name.id}}_relation.insert(self, rel)
        end
      end

      macro has_one(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, join_foreign = nil, dependent = :nullify, inverse_of = nil)
        ::Jennifer::Model::RelationDefinition.declare_dependent({{name}}, {{dependent}}, :has_one)

        @@relations["{{name.id}}"] =
          ::Jennifer::Relation::HasOne({{klass}}, {{@type}}).new("{{name.id}}", {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %})

        {{"{% RELATION_NAMES << #{name.id.stringify} %}".id}}

        @{{name.id}} : {{klass}}?
        @__{{name.id}}_retrieved = false

        # :nodoc:
        private def set_{{name.id}}_relation(object)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = object
          {% if inverse_of %}
            object.not_nil!.set_inverse_of({{inverse_of.id.stringify}}, self) if object
          {% end %}
        end

        def self.{{name.id}}_relation
          @@relations["{{name.id}}"].as(::Jennifer::Relation::HasOne({{klass}}, {{@type}}))
        end

        def {{name.id}}
          if !@__{{name.id}}_retrieved && @{{name.id}}.nil? && !new_record?
            set_{{name.id}}_relation({{name.id}}_reload)
          end
          @{{name.id}}
        end

        def {{name.id}}!
          {{name.id}}.not_nil!
        end

        def {{name.id}}_query
          primary_field = {{ (primary ? primary : "primary").id }}
          @@relations["{{name.id}}"].query(primary_field).as(::Jennifer::QueryBuilder::ModelQuery({{klass}}))
        end

        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.first.as({{klass}}?)
        end

        # ... ; doesn't support `inverse_of` option
        def append_{{name.id}}(rel : Hash)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = {{klass}}.build(rel, false)
        end

        def append_{{name.id}}(rel : {{klass}})
          @__{{name.id}}_retrieved = true
          @{{name.id}} = rel
        end

        def append_{{name.id}}(rel : Jennifer::Model::Resource)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = rel.as({{klass}})
        end

        def __{{name.id}}_retrieved
          @__{{name.id}}_retrieved = true
        end

        def remove_{{name.id}}
          {{@type}}.{{name.id}}_relation.remove(self)
          @{{name.id}} = nil
        end

        def add_{{name.id}}(rel : Hash)
          @{{name.id}} = {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        def add_{{name.id}}(rel : {{klass}})
          @{{name.id}} = {{@type}}.{{name.id}}_relation.insert(self, rel)
        end
      end

      macro inherited_hook
        RELATION_NAMES = [] of String

        def set_inverse_of(name : String, object)
          \{% begin %}
            \{% relations = RELATION_NAMES %}
            \{% if relations.size > 0 %}
              case name
              \{% for rel in relations %}
                when \{{rel}}
                  @\{{rel.id}} = object
                  __\{{rel.id}}_retrieved
              \{% end %}
              else
                super(name, object)
              end
            \{% else %}
              super(name, object)
            \{% end %}
          \{% end %}
        end

        def append_relation(name : String, hash)
          \{% begin %}
            \{% relations = RELATION_NAMES %}
            \{% if relations.size > 0 %}
              case name
              \{% for rel in relations %}
              when \{{rel}}
                append_\{{rel.id}}(hash)
              \{% end %}
              else
                super(name, hash)
              end
            \{% else %}
              super(name, hash)
            \{% end %}
          \{% end %}
        end

        def relation_retrieved(name : String)
          \{% begin %}
            \{% relations = RELATION_NAMES %}
            \{% if relations.size > 0 %}
              case name
              \{% for rel in relations %}
                when \{{rel}}
                  __\{{rel.id}}_retrieved
              \{% end %}
              else
                super(name)
              end
            \{% else %}
              super(name)
            \{% end %}
          \{% end %}
        end

        def get_relation(name : String)
          \{% begin %}
            \{% relations = RELATION_NAMES %}
            \{% if relations.size > 0 %}
              case name
              \{% for rel in relations %}
                when \{{rel}}
                  \{{rel.id}}
              \{% end %}
              else
                super(name)
              end
            \{% else %}
              super(name)
            \{% end %}
          \{% end %}
        end

        def __refresh_relation_retrieves
          \{% begin %}
            \{% relations = RELATION_NAMES %}
            \{% for rel in relations %}
              @__\{{rel.id}}_retrieved = false
            \{% end %}
            super
          \{% end %}
        end
      end
    end
  end
end
