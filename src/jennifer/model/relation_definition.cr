module Jennifer
  module Model
    module RelationDefinition
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

      macro included
        macro has_many(name, klass, request = nil, foreign = nil, primary = nil, dependent = :nullify)
          ::Jennifer::Model::RelationDefinition.declare_dependent(\{{name}}, \{{dependent}}, :has_many)

          @@relations["\{{name.id}}"] =
            ::Jennifer::Relation::HasMany(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})

          \{% RELATION_NAMES << "#{name.id}" %}

          @\{{name.id}} = [] of \{{klass}}
          @__\{{name.id}}_retrived = false

          # returns relation metaobject
          def self.\{{name.id}}_relation
            @@\{{name.id}}_relation ||= ::Jennifer::Relation::HasMany(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})
          end

          # returns relation query for the object
          def \{{name.id}}_query
            primary_value = \{{ primary ? primary.id : "primary".id }}
            \{{@type}}.relation(\{{name.id.stringify}}).query(primary_value).as(::Jennifer::QueryBuilder::ModelQuery(\{{klass}}))
          end

          # returns array of related objects
          def \{{name.id}}
            if !@__\{{name.id}}_retrived && @\{{name.id}}.empty?
              @__\{{name.id}}_retrived = true
              @\{{name.id}} = \{{name.id}}_query.to_a.as(Array(\{{klass}}))
            end
            @\{{name.id}}
          end

          # builds related object from hash
          def append_\{{name.id}}(rel : Hash)
            @__\{{name.id}}_retrived = true
            @\{{name.id}} << \{{klass}}.build(rel, false)
          end

          def append_\{{name.id}}(rel : \{{klass}})
            @__\{{name.id}}_retrived = true
            @\{{name.id}} << rel
          end

          # removes given object from relation array
          def remove_\{{name.id}}(rel : \{{klass}})
            index = @\{{name.id}}.index { |e| e.primary == rel.primary }
            if index
              \{{@type}}.\{{name.id}}_relation.remove(self, rel)
              @\{{name.id}}.delete_at(index)
            end
            rel
          end

          def add_\{{name.id}}(rel : Hash)
            @\{{name.id}} << \{{@type}}.\{{name.id}}_relation.insert(self, rel).as(\{{klass}})
          end

          def add_\{{name.id}}(rel : \{{klass}})
            @\{{name.id}} << \{{@type}}.\{{name.id}}_relation.insert(self, rel)
          end

          def \{{name.id}}_reload
            @\{{name.id}} = \{{name.id}}_query.to_a.as(Array(\{{klass}}))
          end
        end

        macro has_and_belongs_to_many(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, association_foreign = nil)
          @@relations["\{{name.id}}"] =
            ::Jennifer::Relation::ManyToMany(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{{ (request ? ".exec #{request} ," : "").id }}, \{{join_table}}, \{{association_foreign}})

          \{% RELATION_NAMES << "#{name.id}" %}

          before_destroy :__\{{name.id}}_clean

          # Cleans up all join table records for given relation
          def __\{{name.id}}_clean
            relation = self.class.\{{name.id}}_relation
            this = self
            ::Jennifer::Adapter.adapter.delete(::Jennifer::QueryBuilder::Query.new(relation.join_table!).where do
              c(relation.foreign_field) == this.attribute(relation.primary_field)
            end)
          end

          @\{{name.id}} = [] of \{{klass}}
          @__\{{name.id}}_retrived = false

          def self.\{{name.id}}_relation
            @@\{{name.id}}_relation ||= ::Jennifer::Relation::ManyToMany(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{{ (request ? ".exec #{request} ," : "").id }}, \{{join_table}}, \{{association_foreign}})
          end

          def \{{name.id}}_query
            primary_field =
              \{% if primary %}
                \{{primary.id}}
              \{% else %}
                primary
              \{% end %}
            @@relations["\{{name.id}}"].query(primary_field).as(::Jennifer::QueryBuilder::ModelQuery(\{{klass}}))
          end

          def \{{name.id}}
            if !@__\{{name.id}}_retrived && @\{{name.id}}.empty?
              @__\{{name.id}}_retrived = true
              @\{{name.id}} = \{{name.id}}_query.to_a.as(Array(\{{klass}}))
            end
            @\{{name.id}}
          end

          def append_\{{name.id}}(rel : Hash)
            @__\{{name.id}}_retrived = true
            @\{{name.id}} << \{{klass}}.build(rel, false)
          end

          def append_\{{name.id}}(rel : \{{klass}})
            @__\{{name.id}}_retrived = true
            @\{{name.id}} << rel
          end

          def remove_\{{name.id}}(rel : \{{klass}})
            index = @\{{name.id}}.index { |e| e.primary == rel.primary }
            if index
              \{{@type}}.\{{name.id}}_relation.remove(self, rel)
              @\{{name.id}}.delete_at(index)
            end
            rel
          end

          def add_\{{name.id}}(rel : Hash)
            @\{{name.id}} << \{{@type}}.\{{name.id}}_relation.insert(self, rel)
          end

          def add_\{{name.id}}(rel : \{{klass}})
            @\{{name.id}} << \{{@type}}.\{{name.id}}_relation.insert(self, rel)
          end

          def \{{name.id}}_reload
            @\{{name.id}} = \{{name.id}}_query.to_a.as(Array(\{{klass}}))
          end
        end

        macro belongs_to(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, join_foreign = nil, dependent = :none)
          ::Jennifer::Model::RelationDefinition.declare_dependent(\{{name}}, \{{dependent}}, :belongs_to)

          @@relations["\{{name.id}}"] =
            ::Jennifer::Relation::BelongsTo(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})

          \{% RELATION_NAMES << "#{name.id}" %}

          @\{{name.id}} : \{{klass}}?
          @__\{{name.id}}_retrived = false

          def self.\{{name.id}}_relation
            @@\{{name.id}}_relation ||= ::Jennifer::Relation::BelongsTo(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})
          end

          def \{{name.id}}
            if !@__\{{name.id}}_retrived && @\{{name.id}}.nil?
              @__\{{name.id}}_retrived = true
              @\{{name.id}} = \{{name.id}}_reload
            end
            @\{{name.id}}
          end

          def \{{name.id}}!
            \{{name.id}}.not_nil!
          end

          def \{{name.id}}_query
            foreign_field = \{{ (foreign ? foreign : "attribute(#{klass}.singular_table_name + \"_id\")").id }}
            @@relations["\{{name.id}}"].query(foreign_field).as(::Jennifer::QueryBuilder::ModelQuery(\{{klass}}))
          end

          def \{{name.id}}_reload
            @\{{name.id}} = \{{name.id}}_query.first.as(\{{klass}}?)
          end

          def append_\{{name.id}}(rel : Hash)
            @__\{{name.id}}_retrived = true
            @\{{name.id}} = \{{klass}}.build(rel, false)
          end

          def append_\{{name.id}}(rel : \{{klass}})
            @__\{{name.id}}_retrived = true
            @\{{name.id}} = rel
          end

          def remove_\{{name.id}}
            \{{@type}}.\{{name.id}}_relation.remove(self)
            @\{{name.id}} = nil
          end

          def add_\{{name.id}}(rel : Hash)
            @\{{name.id}} = \{{@type}}.\{{name.id}}_relation.insert(self, rel)
          end

          def add_\{{name.id}}(rel : \{{klass}})
            @\{{name.id}} = \{{@type}}.\{{name.id}}_relation.insert(self, rel)
          end
        end

        macro has_one(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, join_foreign = nil, dependent = :nullify)
          ::Jennifer::Model::RelationDefinition.declare_dependent(\{{name}}, \{{dependent}}, :has_one)

          @@relations["\{{name.id}}"] =
            ::Jennifer::Relation::HasOne(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})

          \{% RELATION_NAMES << "#{name.id}" %}

          @\{{name.id}} : \{{klass}}?
          @__\{{name.id}}_retrived = false

          def self.\{{name.id}}_relation
            @@\{{name.id}}_relation ||= ::Jennifer::Relation::HasOne(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})
          end

          def \{{name.id}}
            if !@__\{{name.id}}_retrived && @\{{name.id}}.nil?
              @__\{{name.id}}_retrived = true
              @\{{name.id}} = \{{name.id}}_reload
            end
            @\{{name.id}}
          end

          def \{{name.id}}!
            \{{name.id}}.not_nil!
          end

          def \{{name.id}}_query
            primary_field = \{{ (primary ? primary : "primary").id }}
            @@relations["\{{name.id}}"].query(primary_field).as(::Jennifer::QueryBuilder::ModelQuery(\{{klass}}))
          end

          def \{{name.id}}_reload
            @\{{name.id}} = \{{name.id}}_query.first.as(\{{klass}}?)
          end

          def append_\{{name.id}}(rel : Hash)
            @__\{{name.id}}_retrived = true
            @\{{name.id}} = \{{klass}}.build(rel, false)
          end

          def append_\{{name.id}}(rel : \{{klass}})
            @__\{{name.id}}_retrived = true
            @\{{name.id}} = rel
          end

          def remove_\{{name.id}}
            \{{@type}}.\{{name.id}}_relation.remove(self)
            @\{{name.id}} = nil
          end

          def add_\{{name.id}}(rel : Hash)
            @\{{name.id}} = \{{@type}}.\{{name.id}}_relation.insert(self, rel)
          end

          def add_\{{name.id}}(rel : \{{klass}})
            @\{{name.id}} = \{{@type}}.\{{name.id}}_relation.insert(self, rel)
          end
        end

        macro update_relation_methods
          def append_relation(name, hash)
            \\{% if RELATION_NAMES.size > 0 %}
              case name
              \\{% for rel in RELATION_NAMES %}
                when \\{{rel}}
                  append_\\{{rel.id}}(hash)
              \\{% end %}
              else
                super(name, hash)
              end
            \\{% end %}
          end
        end
      end

      macro finished_hook
        update_relation_methods

        def __refresh_relation_retrieves
          \{% for rel in RELATION_NAMES %}
            @__\{{rel.id}}_retrived = false
          \{% end %}
        end
      end

      macro inherited_hook
        RELATION_NAMES = [] of String
      end
    end
  end
end
