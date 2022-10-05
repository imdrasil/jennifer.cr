module Jennifer
  module Model
    module RelationDefinition
      protected def __refresh_relation_retrieves
      end

      def append_relation(name : String, hash)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      def relation_retrieved(name : String)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      abstract def set_inverse_of(name : String, object)
      abstract def get_relation(name : String)

      # :nodoc:
      macro nullify_dependency(name, relation_type, polymorphic)
        # :nodoc:
        def __nullify_callback_{{name.id}}
          rel = self.class.{{name.id}}_relation
          options = {rel.foreign_field => nil}
          {% if polymorphic %} options[rel.foreign_type] = nil {% end %}
          {{name.id}}_query.update(options)
        end

        before_destroy :__nullify_callback_{{name.id}}
      end

      # :nodoc:
      macro delete_dependency(name, relation_type, polymorphic)
        # :nodoc:
        def __delete_callback_{{name.id}}
          {{name.id}}_query.delete
        end

        before_destroy :__delete_callback_{{name.id}}
      end

      # :nodoc:
      macro destroy_dependency(name, relation_type, polymorphic)
        # :nodoc:
        def __destroy_callback_{{name.id}}
          {% if polymorphic && relation_type.id.stringify == "belongs_to" %}
            self.class.{{name.id}}_relation.destroy(self)
          {% else %}
            {{name.id}}_query.destroy
          {% end %}
        end

        before_destroy :__destroy_callback_{{name.id}}
      end

      # :nodoc:
      macro restrict_with_exception_dependency(name, relation_type, polymorphic)
        # :nodoc:
        def __restrict_with_exception_callback_{{name.id}}
          raise ::Jennifer::RecordExists.new(self, {{name.id.stringify}}) if {{name.id}}_query.exists?
        end

        before_destroy :__restrict_with_exception_callback_{{name.id}}
      end

      # :nodoc:
      macro declare_dependent(name, type, relation_type, polymorphic = false)
        {% type = type.id.stringify %}
        {% if relation_type == :belongs_to && type == "nullify" %}
          {% raise "Relation \"#{name}\" can't has belongs_to relation with dependent nullify" %}
        {% end %}
        {% if type == "nullify" %}
          ::Jennifer::Model::RelationDefinition.nullify_dependency({{name}}, {{relation_type}}, {{polymorphic}})
        {% elsif type == "delete" %}
          ::Jennifer::Model::RelationDefinition.delete_dependency({{name}}, {{relation_type}}, {{polymorphic}})
        {% elsif type == "destroy" %}
          ::Jennifer::Model::RelationDefinition.destroy_dependency({{name}}, {{relation_type}}, {{polymorphic}})
        {% elsif type == "restrict_with_exception" %}
          ::Jennifer::Model::RelationDefinition.restrict_with_exception_dependency({{name}}, {{relation_type}}, {{polymorphic}})
        {% elsif type == "none" %}
        {% else %}
          {% raise "Dependency type #{type} for relation #{name} of #{@type} is not allowed." %}
        {% end %}
      end

      # Specifies a one-to-many association.
      #
      # Options:
      #
      # - *name* - relation name
      # - *klass* - specify the class name of the association
      # - *request* - extra request scope to retrieve a specific set of records when access the associated collection
      # (ATM only `WHERE` conditions are respected)
      # - *foreign* - specify the foreign key used for the association
      # - *foreign_type* - specify the column used to store  the associated object's type,
      # if this is a polymorphic relation
      # - *primary* - specify the name of the column to use as the primary key for the relation
      # - *dependent* - specify the destroy strategy of the associated objects when their owner is destroyed;
      # available options are: `destroy`, `delete`, `nullify`, `restrict_with_exception`
      # - *inverse_of* - specifies the name of the `belongs_to` relation on the associated object that is the inverse of this relation;
      # required for polymorphic relation
      # - *polymorphic* - specifies that this relation is a polymorphic
      #
      # The following methods for retrieval and query of a single associated object will be added:
      #
      # `association` is a placeholder for the symbol passed as the name argument.
      #
      # - `.association_relation` - returns `association` relation
      # - `#association` - returns array of related objects
      # - `#append_association(rel)` - builds related object from hash (or use given instance) and adds to relation
      # - `#add_association(rel)` - insert given object to db and relation; doesn't support `inverse_of` option
      # - `#remove_association(rel)` - removes given object from relation array
      # - `#association_query` - returns `association` relation query for the object
      # - `#association_reload` - reloads related objects from the DB.
      macro has_many(name, klass, request = nil, foreign = nil, foreign_type = nil, primary = nil, dependent = :nullify, inverse_of = nil, polymorphic = false)
        {{"{% RELATION_NAMES << #{name.id.stringify} %}".id}}
        ::Jennifer::Model::RelationDefinition.declare_dependent({{name}}, {{dependent}}, :has_many, {{polymorphic}})

        RELATIONS["{{name.id}}"] =
          {% if polymorphic %}
            {% relation_class = "::Jennifer::Relation::PolymorphicHasMany(#{klass}, #{@type})".id %}
            {% if inverse_of.nil? %} {% raise "`inverse_of` is required for a polymorphic has_many relation." %} {% end %}
            {{relation_class}}.new("{{name.id}}", {{foreign}}, {{primary}},
              {{klass}}.all{% if request %}.exec {{request}} {% end %}, foreign_type: {{foreign_type}}, inverse_of: {{inverse_of}})
          {% else %}
            {% relation_class = "::Jennifer::Relation::HasMany(#{klass}, #{@type})".id %}
            {{relation_class}}.new("{{name.id}}", {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %})
          {% end %}
        @[JSON::Field(ignore: true)]
        @{{name.id}} = [] of {{klass}}
        @[JSON::Field(ignore: true)]
        @__{{name.id}}_retrieved = false

        private def set_{{name.id}}_relation(collection : Array)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = collection
          {% if inverse_of %} collection.each(&.append_{{inverse_of.id}}(self)) {% end %}
        end

        private def set_{{name.id}}_relation(object)
          @__{{name.id}}_retrieved = true
          @{{name.id}} << object
          {% if inverse_of %} object.append_{{inverse_of.id}}(self) {% end %}
        end

        # :nodoc:
        def self.{{name.id}}_relation
          RELATIONS["{{name.id}}"].as({{relation_class}})
        end

        # :nodoc:
        def {{name.id}}_query
          primary_value = {{ primary ? primary.id : "primary".id }}
          {{@type}}.{{name.id}}_relation.query(primary_value).as(::Jennifer::QueryBuilder::ModelQuery({{klass}}))
        end

        # :nodoc:
        def {{name.id}}
          if !@__{{name.id}}_retrieved && @{{name.id}}.empty? && !new_record?
            set_{{name.id}}_relation({{name.id}}_query.to_a.as(Array({{klass}})))
          end
          @{{name.id}}
        end

        # :nodoc:
        def append_{{name.id}}(rel : Hash)
          obj = {{klass}}.new(rel, false)
          set_{{name.id}}_relation(obj)
          obj
        end

        # :nodoc:
        def append_{{name.id}}(rel : {{klass}})
          set_{{name.id}}_relation(rel)
          rel
        end

        # :nodoc:
        def append_{{name.id}}(rel : Jennifer::Model::Resource)
          obj = rel.as({{klass}})
          set_{{name.id}}_relation(obj)
          obj
        end

        # :nodoc:
        def remove_{{name.id}}(rel : {{klass}})
          index = @{{name.id}}.index { |e| e.primary == rel.primary }
          if index
            {{@type}}.{{name.id}}_relation.remove(self, rel)
            @{{name.id}}.delete_at(index)
          end
          rel
        end

        # :nodoc:
        def add_{{name.id}}(rel : Hash)
          @{{name.id}} << {{@type}}.{{name.id}}_relation.insert(self, rel).as({{klass}})
        end

        # :nodoc:
        def add_{{name.id}}(rel : {{klass}})
          @{{name.id}} << {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        # :nodoc:
        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.to_a.as(Array({{klass}}))
        end
      end

      # Specifies a many-to-many relationship with another class.
      #
      # This associates two classes via an intermediate join table. Unless the join table is explicitly specified as an option,
      # it is guessed using the lexical order of the class names.
      # So a join between Developer and Project will give the default join table name of "developers_projects" because "D" precedes "P" alphabetically.
      # Note that this precedence is calculated using the < operator for String. This means that if the strings are of different lengths, and
      # the strings are equal when compared up to the shortest length, then the longer string is considered of higher lexical precedence than the shorter one.
      #
      # Options:
      #
      # - *name* - relation name
      # - *klass* - specify the class name of the association
      # - *request* - extra request scope to retrieve a specific set of records when access the associated collection
      # (ATM only `WHERE` conditions are respected)
      # - *foreign* - specify the foreign key used for the association
      # - *primary* - specify the name of the column to use as the primary key for the relation
      # - *join_table* - specifies the name of the join table if the default based on lexical order isn't what you want
      # - *association_foreign* - specifies the foreign key used for the association on the receiving side of the association
      #
      # The following methods for retrieval and query of a single associated object will be added:
      #
      # `association` is a placeholder for the symbol passed as the name argument.
      #
      # - `.association_relation`
      # - `#association`
      # - `#append_association(rel)`
      # - `#add_association(rel)`
      # - `#remove_association(rel)`
      # - `#association_query`
      # - `#association_reload`
      macro has_and_belongs_to_many(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, association_foreign = nil)
        {{"{% RELATION_NAMES << #{name.id.stringify} %}".id}}
        RELATIONS["{{name.id}}"] =
          ::Jennifer::Relation::ManyToMany({{klass}}, {{@type}}).new("{{name.id}}", {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %}, {{join_table}}, {{association_foreign}})

        before_destroy :__{{name.id}}_clean

        # :nodoc:
        def __{{name.id}}_clean
          relation = self.class.{{name.id}}_relation
          this = self
          self.class.adapter.delete(::Jennifer::QueryBuilder::Query.new(relation.join_table!).where do
            c(relation.foreign_field) == this.attribute(relation.primary_field)
          end)
        end

        @[JSON::Field(ignore: true)]
        @{{name.id}} = [] of {{klass}}
        @[JSON::Field(ignore: true)]
        @__{{name.id}}_retrieved = false

        private def set_{{name.id}}_relation(object : Array)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = object
        end

        private def set_{{name.id}}_relation(object)
          @__{{name.id}}_retrieved = true
          @{{name.id}} << object
        end

        # :nodoc:
        def self.{{name.id}}_relation
          RELATIONS["{{name.id}}"].as(::Jennifer::Relation::ManyToMany({{klass}}, {{@type}}))
        end

        # :nodoc:
        def {{name.id}}_query
          primary_field = {% if primary %} {{primary.id}} {% else %} primary {% end %}
          RELATIONS["{{name.id}}"].query(primary_field).as(::Jennifer::QueryBuilder::ModelQuery({{klass}}))
        end

        def {{name.id}}
          if !@__{{name.id}}_retrieved && @{{name.id}}.empty? && !new_record?
            set_{{name.id}}_relation({{name.id}}_query.to_a.as(Array({{klass}})))
          end
          @{{name.id}}
        end

        # :nodoc:
        def append_{{name.id}}(rel : Hash)
          obj = {{klass}}.new(rel, false)
          set_{{name.id}}_relation(obj)
          obj
        end

        # :nodoc:
        def append_{{name.id}}(rel : {{klass}})
          set_{{name.id}}_relation(rel)
          rel
        end

        # :nodoc:
        def append_{{name.id}}(rel : Jennifer::Model::Resource)
          set_{{name.id}}_relation(rel.as({{klass}}))
          rel
        end

        # :nodoc:
        def remove_{{name.id}}(rel : {{klass}})
          index = @{{name.id}}.index { |e| e.primary == rel.primary }
          if index
            {{@type}}.{{name.id}}_relation.remove(self, rel)
            @{{name.id}}.delete_at(index)
          end
          rel
        end

        # :nodoc:
        def add_{{name.id}}(rel : Hash)
          @{{name.id}} << {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        # :nodoc:
        def add_{{name.id}}(rel : {{klass}})
          @{{name.id}} << {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        # :nodoc:
        def {{name.id}}_reload
          @{{name.id}} = {{name.id}}_query.to_a.as(Array({{klass}}))
        end
      end

      private macro polymorphic_belongs_to(name, klass, request, foreign, foreign_type, primary, dependent)
        {% relation_class = "#{name.id.camelcase}Relation".id %}

        ::Jennifer::Relation::IPolymorphicBelongsTo.define_relation_class({{name}}, {{@type}}, {{klass}}, {{klass.type_vars[0].types}}, {{request}})

        RELATIONS["{{name.id}}"] =
          {{relation_class}}.new("{{name.id}}", {{foreign}}, {{primary}}, {{foreign_type}})

        # :nodoc:
        def self.{{name.id}}_relation
          RELATIONS["{{name.id}}"].as({{relation_class}})
        end

        {% for type in klass.type_vars[0].types %}
          {% related_name = type.id.split("::")[-1].underscore.id %}
          def {{name.id}}_{{related_name}}
            {{name.id}}.as({{type}})
          end

          # :nodoc:
          def {{name.id}}_{{related_name}}?
            {{name.id}}.is_a?({{type}})
          end
        {% end %}

        # :nodoc:
        def {{name.id}}_query
          foreign_field = {{ (foreign ? foreign : "#{name.id}_id").id }}
          polymorphic_type = {{ (foreign_type ? foreign_type : "#{name.id}_type").id }}

          self.class.{{name.id}}_relation.query(foreign_field, polymorphic_type)
        end

        # :nodoc:
        def {{name.id}}_reload
          foreign_field = {{ (foreign ? foreign : "#{name.id}_id").id }}
          polymorphic_type = {{ (foreign_type ? foreign_type : "#{name.id}_type").id }}

          @{{name.id}} = self.class.{{name.id}}_relation.load(foreign_field, polymorphic_type)
        end

        # :nodoc:
        def append_{{name.id}}(rel : Hash)
          raise ::Jennifer::BaseException.new("Polymorphic relation can't be loaded dynamically.")
        end
      end

      # Specifies a one-to-one association with another class.
      #
      # This macro should only be used if this class contains the foreign key.
      # If the other class contains the foreign key, then you should use has_one instead.
      #
      # Options:
      #
      # - *name* - relation name
      # - *klass* - specify the class name of the association; in case of polymorphic relation use `Union(Class1 | Class2)` syntax
      # - *request* - extra request scope to retrieve a specific set of records when access the associated collection
      # (ATM only `WHERE` conditions are respected)
      # - *foreign* - specify the foreign key used for the association
      # - *primary* - specify the name of the column to use as the primary key for the relation
      # - *dependent* - specify the destroy strategy of the associated objects when their owner is destroyed;
      # available options are: `destroy`, `delete`, `nullify` (exception is polymorphic relation), `restrict_with_exception`
      # - *polymorphic* - passing `true` indicates that this is a polymorphic association
      # - *foreign_type* - specify the column used to store the associated object's type,
      # if this is a polymorphic relation
      # - *required* - passing `true` will validate presence of related object; by default it is `false`
      #
      # Methods will be added for retrieval and query for a single associated object, for which this object holds an id:
      #
      # `association` is a placeholder for the symbol passed as the `name` argument.
      #
      # - `.association_relation`
      # - `#association`
      # - `#association!`
      # - `#append_association(rel)`
      # - `#add_association(rel)`
      # - `#remove_association`
      # - `#association_query`
      # - `#association_reload`
      #
      # Polymorphic relation also generates next methods
      #
      # - `#association_class_name` - returns casted related object to `ClassName`
      # - `#association_class_name?` - returns whether related object is a `ClassName`
      macro belongs_to(name, klass, request = nil, foreign = nil, primary = nil, dependent = :none, polymorphic = false, foreign_type = nil, required = false)
        {{"{% RELATION_NAMES << #{name.id.stringify} %}".id}}
        ::Jennifer::Model::RelationDefinition.declare_dependent({{name}}, {{dependent}}, :belongs_to, {{polymorphic}})

        {% if required %}
          {% message = required.is_a?(BoolLiteral) ? :required : required %}
          validates_presence :{{name.id}}, message: {{message}}
        {% end %}

        @[JSON::Field(ignore: true)]
        @{{name.id}} : {{klass}}?
        @[JSON::Field(ignore: true)]
        @__{{name.id}}_retrieved = false

        def {{name.id}}
          if !@__{{name.id}}_retrieved && @{{name.id}}.nil? && !new_record?
            @__{{name.id}}_retrieved = true
            @{{name.id}} = {{name.id}}_reload
          end
          @{{name.id}}
        end

        # :nodoc:
        def {{name.id}}!
          {{name.id}}.not_nil!
        end

        # :nodoc:
        def append_{{name.id}}(rel : {{klass}})
          @__{{name.id}}_retrieved = true
          @{{name.id}} = rel
        end

        # :nodoc:
        def append_{{name.id}}(rel : Jennifer::Model::Resource)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = rel.as({{klass}})
        end

        # :nodoc:
        def add_{{name.id}}(rel : Hash)
          @{{name.id}} = {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        # :nodoc:
        def add_{{name.id}}(rel : {{klass}})
          @{{name.id}} = {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        # :nodoc:
        def remove_{{name.id}}
          {{@type}}.{{name.id}}_relation.remove(self)
          @{{name.id}} = nil
        end

        {% if polymorphic %}
          polymorphic_belongs_to({{name}}, {{klass}}, {{request}}, {{foreign}}, {{foreign_type}}, {{primary}},  {{dependent}})
        {% else %}
          {% relation_class = "::Jennifer::Relation::BelongsTo(#{klass}, #{@type})".id %}

          RELATIONS["{{name.id}}"] =
            {{relation_class}}.new("{{name.id}}", {{foreign}}, {{primary}}, {{klass}}.all{% if request %}.exec {{request}} {% end %})

          # :nodoc:
          def self.{{name.id}}_relation
            RELATIONS["{{name.id}}"].as({{relation_class}})
          end

          # :nodoc:
          def {{name.id}}_query
            foreign_field = {{ (foreign ? foreign : "attribute(#{klass}.foreign_key_name)").id }}
            self.class.{{name.id}}_relation.query(foreign_field).as(::Jennifer::QueryBuilder::ModelQuery({{klass}}))
          end

          # :nodoc:
          def {{name.id}}_reload
            @{{name.id}} = {{name.id}}_query.first.as({{klass}}?)
          end

          # :nodoc:
          def append_{{name.id}}(rel : Hash)
            @__{{name.id}}_retrieved = true
            @{{name.id}} = {{klass}}.new(rel, false)
          end
        {% end %}
      end

      # Specifies a one-to-one association with another class.
      #
      # This macro should only be used if the other class contains the foreign key.
      # If the current class contains the foreign key, then you should use belongs_to instead.
      #
      # Options:
      #
      # - *name* - relation name
      # - *klass* - specify the class name of the association
      # - *request* - extra request scope to retrieve a specific set of records when access the associated collection
      # (ATM only `WHERE` conditions are respected)
      # - *foreign* - specify the foreign key used for the association
      # - *foreign_type* - specify the column used to store the associated object's type,
      # if this is a polymorphic relation
      # - *primary* - specify the name of the column to use as the primary key for the relation
      # - *dependent* - specify the destroy strategy of the associated objects when their owner is destroyed;
      # available options are: `destroy`, `delete`, `nullify`, `restrict_with_exception`
      # - *inverse_of* - specifies the name of the `belongs_to` relation on the associated object that is the inverse of this relation;
      # required for polymorphic relation
      # - *polymorphic* - passing `true` indicates that this is a polymorphic association
      #
      # The following methods for retrieval and query of a single associated object will be added:
      #
      # `association` is a placeholder for the symbol passed as the name argument.
      #
      # - `.association_relation`
      # - `#association`
      # - `#association!`
      # - `#append_association(rel)`
      # - `#add_association(rel)`
      # - `#remove_association`
      # - `#association_query`
      # - `#association_reload`
      macro has_one(name, klass, request = nil, foreign = nil, foreign_type = nil, primary = nil, dependent = :nullify, inverse_of = nil, polymorphic = false)
        {{"{% RELATION_NAMES << #{name.id.stringify} %}".id}}
        ::Jennifer::Model::RelationDefinition.declare_dependent({{name}}, {{dependent}}, :has_one)

        RELATIONS["{{name.id}}"] =
          {% if polymorphic %}
            {% relation_class = "::Jennifer::Relation::PolymorphicHasOne(#{klass}, #{@type})".id %}
            {% if inverse_of.nil? %} {% raise "`inverse_of` is required for a polymorphic has_many relation." %} {% end %}
            {{relation_class}}.new("{{name.id}}", {{foreign}}, {{primary}},
              {{klass}}.all{% if request %}.exec {{request}} {% end %}, foreign_type: {{foreign_type}}, inverse_of: {{inverse_of}})
          {% else %}
            {% relation_class = "::Jennifer::Relation::HasOne(#{klass}, #{@type})".id %}
            {{relation_class}}.new("{{name.id}}", {{foreign}}, {{primary}},
            {{klass}}.all{% if request %}.exec {{request}} {% end %})
          {% end %}

        @[JSON::Field(ignore: true)]
        @{{name.id}} : {{klass}}?
        @[JSON::Field(ignore: true)]
        @__{{name.id}}_retrieved = false

        private def set_{{name.id}}_relation(object)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = object
          {% if inverse_of %}
            object.not_nil!.append_{{inverse_of.id}}(self) if object
          {% end %}
        end

        # :nodoc:
        def self.{{name.id}}_relation
          RELATIONS["{{name.id}}"].as({{relation_class}})
        end

        def {{name.id}}
          if !@__{{name.id}}_retrieved && @{{name.id}}.nil? && !new_record?
            set_{{name.id}}_relation({{name.id}}_reload)
          end
          @{{name.id}}
        end

        # :nodoc:
        def {{name.id}}!
          {{name.id}}.not_nil!
        end

        # :nodoc:
        def {{name.id}}_query
          primary_field = {{ (primary ? primary : "primary").id }}
          self.class.{{name.id}}_relation.query(primary_field).as(::Jennifer::QueryBuilder::ModelQuery({{klass}}))
        end

        # :nodoc:
        def {{name.id}}_reload
          @__{{name.id}}_retrieved = true
          @{{name.id}} = {{name.id}}_query.first.as({{klass}}?)
        end

        # :nodoc:
        def append_{{name.id}}(rel : Hash)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = {{klass}}.new(rel, false)
        end

        # :nodoc:
        def append_{{name.id}}(rel : {{klass}})
          @__{{name.id}}_retrieved = true
          @{{name.id}} = rel
        end

        # :nodoc:
        def append_{{name.id}}(rel : Jennifer::Model::Resource)
          @__{{name.id}}_retrieved = true
          @{{name.id}} = rel.as({{klass}})
        end

        # :nodoc:
        def remove_{{name.id}}
          {{@type}}.{{name.id}}_relation.remove(self)
          @{{name.id}} = nil
        end

        # :nodoc:
        def add_{{name.id}}(rel : Hash)
          @{{name.id}} = {{@type}}.{{name.id}}_relation.insert(self, rel)
        end

        # :nodoc:
        def add_{{name.id}}(rel : {{klass}})
          @{{name.id}} = {{@type}}.{{name.id}}_relation.insert(self, rel)
        end
      end

      # :nodoc:
      macro inherited_hook
        # :nodoc:
        RELATION_NAMES = [] of String
        # :nodoc:
        RELATIONS = {} of String => ::Jennifer::Relation::IRelation

        {% verbatim do %}
          # :nodoc:
          def append_relation(name : String, hash_or_object)
            {% if !RELATION_NAMES.empty? %}
              case name
              {% for rel in RELATION_NAMES %}
              when {{rel}}
                append_{{rel.id}}(hash_or_object)
              {% end %}
              else
                super(name, hash_or_object)
              end
            {% else %}
              super(name, hash_or_object)
            {% end %}
          end

          # :nodoc:
          def relation_retrieved(name : String)
            {% if !RELATION_NAMES.empty? %}
              case name
              {% for rel in RELATION_NAMES %}
                when {{rel}}
                  @__{{rel.id}}_retrieved = true
              {% end %}
              else
                super(name)
              end
            {% else %}
              super(name)
            {% end %}
          end

          # :nodoc:
          def get_relation(name : String)
            {% relations = RELATION_NAMES %}
            {% if relations.size > 0 %}
              case name
              {% for rel in relations %}
                when {{rel}}
                  {{rel.id}}
              {% end %}
              else
                super(name)
              end
            {% else %}
              super(name)
            {% end %}
          end

          protected def __refresh_relation_retrieves
            {% for rel in RELATION_NAMES %}
              @__{{rel.id}}_retrieved = false
            {% end %}
            super
          end
        {% end %}
      end
    end
  end
end
