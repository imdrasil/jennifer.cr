module Jennifer
  module Model
    module RelationDefinition
      macro included
        macro has_many(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, join_foreign = nil)
          @@relations["\{{name.id}}"] =
            ::Jennifer::Relation::HasMany(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})

          \{% RELATION_NAMES << "#{name.id}" %}

          @\{{name.id}} = [] of \{{klass}}

          # returns relation metaobject
          def self.\{{name.id}}_relation
            @@\{{name.id}}_relation ||= ::Jennifer::Relation::HasMany(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})
          end

          # returns relation query for the object
          def \{{name.id}}_query
            primary_value = \{{ primary ? primary.id : "primary".id }}
            \{{@type}}.relation(\{{name.id.stringify}}).query(primary_value)
          end

          # returns array of related objects
          def \{{name.id}}
            @\{{name.id}} = \{{name.id}}_query.to_a.as(Array(\{{klass}})) if @\{{name.id}}.empty?
            @\{{name.id}}
          end

          # builds related object from hash
          def append_\{{name.id}}(rel : Hash)
            @\{{name.id}} << \{{klass}}.build(rel, false)
          end

          def append_\{{name.id}}(rel : \{{klass}})
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

        macro has_and_belongs_to_many(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, join_foreign = nil)
          @@relations["\{{name.id}}"] =
            ::Jennifer::Relation::ManyToMany(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{{ (request ? ".exec #{request} ," : "").id }}, \{{join_table}}, \{{join_foreign}})

          \{% RELATION_NAMES << "#{name.id}" %}

          before_destroy :__\{{name.id}}_clean

          def __\{{name.id}}_clean
            relation = self.class.\{{name.id}}_relation
            this = self
            ::Jennifer::Adapter.adapter.delete(::Jennifer::QueryBuilder::Query.new(relation.join_table!).where do
              c(relation.foreign_field) == this.attribute(relation.primary_field)
            end)
          end

          @\{{name.id}} = [] of \{{klass}}

          def self.\{{name.id}}_relation
            @@\{{name.id}}_relation ||= ::Jennifer::Relation::ManyToMany(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{{ (request ? ".exec #{request} ," : "").id }}, \{{join_table}}, \{{join_foreign}})
          end

          def \{{name.id}}_query
            primary_field =
              \{% if primary %}
                \{{primary.id}}
              \{% else %}
                primary
              \{% end %}
            @@relations["\{{name.id}}"].query(primary_field)
          end

          def \{{name.id}}
            @\{{name.id}} = \{{name.id}}_query.to_a.as(Array(\{{klass}})) if @\{{name.id}}.empty?
            @\{{name.id}}
          end

          def append_\{{name.id}}(rel : Hash)
            @\{{name.id}} << \{{klass}}.build(rel, false)
          end

          def append_\{{name.id}}(rel : \{{klass}})
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

        macro belongs_to(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, join_foreign = nil)
          @@relations["\{{name.id}}"] =
            ::Jennifer::Relation::BelongsTo(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})

          \{% RELATION_NAMES << "#{name.id}" %}

          @\{{name.id}} : \{{klass}}?

          def self.\{{name.id}}_relation
            @@\{{name.id}}_relation ||= ::Jennifer::Relation::BelongsTo(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})
          end

          def \{{name.id}}
            if @\{{name.id}}
              @\{{name.id}}
            else
              \{{name.id}}_reload
            end
          end

          def \{{name.id}}!
            \{{name.id}}.not_nil!
          end

          def \{{name.id}}_query
            foreign_field =
              \{% if foreign %}
                \{{foreign.id}}
              \{% else %}
                attribute(\{{klass}}.singular_table_name + "_id")
              \{% end %}
            @@relations["\{{name.id}}"].query(foreign_field)
          end

          def \{{name.id}}_reload
            @\{{name.id}} = \{{name.id}}_query.first.as(\{{klass}}?)
          end

          def append_\{{name.id}}(rel : Hash)
            @\{{name.id}} = \{{klass}}.build(rel, false)
          end

          def append_\{{name.id}}(rel : \{{klass}})
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

        macro has_one(name, klass, request = nil, foreign = nil, primary = nil, join_table = nil, join_foreign = nil)
          @@relations["\{{name.id}}"] =
            ::Jennifer::Relation::HasOne(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})

          \{% RELATION_NAMES << "#{name.id}" %}

          @\{{name.id}} : \{{klass}}?

          def self.\{{name.id}}_relation
            @@\{{name.id}}_relation ||= ::Jennifer::Relation::HasOne(\{{klass}}, \{{@type}}).new("\{{name.id}}", \{{foreign}}, \{{primary}},
              \{{klass}}.all\{% if request %}.exec \{{request}} \{% end %})
          end

          def \{{name.id}}
            if @\{{name.id}}
              @\{{name.id}}
            else
              \{{name.id}}_reload
            end
          end

          def \{{name.id}}!
            \{{name.id}}.not_nil!
          end

          def \{{name.id}}_query
            primary_field =
              \{% if primary %}
                \{{primary.id}}
              \{% else %}
                primary
              \{% end %}

            @@relations["\{{name.id}}"].query(primary_field)
          end

          def \{{name.id}}_reload
            @\{{name.id}} = \{{name.id}}_query.first.as(\{{klass}}?)
          end

          def append_\{{name.id}}(rel : Hash)
            @\{{name.id}} = \{{klass}}.build(rel, false)
          end

          def append_\{{name.id}}(rel : \{{klass}})
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
      end

      macro inherited_hook
        RELATION_NAMES = [] of String
      end
    end
  end
end
