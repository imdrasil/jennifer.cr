module Jennifer
  module Model
    module Scoping
      macro scope(name, &block)
        {% underscored_arg_list = block.args.map(&.stringify).map { |e| "__" + e }.join(", ").id %}

        class Jennifer::QueryBuilder::ModelQuery(T)
          def {{name.id}}({{ block.args.splat }})
            T.{{name.id}}(self, {{block.args.splat}})
          end
        end

        def self.{{name.id}}({{ underscored_arg_list }})
          {{name.id}}(all{% if !block.args.empty? %}, {{underscored_arg_list}} {% end %})
        end

        def self.{{name.id}}(_query : ::Jennifer::QueryBuilder::ModelQuery({{@type}}){% if !block.args.empty? %}, {{ underscored_arg_list }} {% end %})
          {% if !block.args.empty? %}
            {{ block.args.splat }} = {{underscored_arg_list}}
          {% end %}
          _query.exec { {{block.body}} }
        end
      end

      macro scope(name, klass)
        class Jennifer::QueryBuilder::ModelQuery(T)
          def {{name.id}}(*args)
            T.{{name.id}}(self, *args)
          end
        end

        def self.{{name.id}}(_query : ::Jennifer::QueryBuilder::ModelQuery({{@type}}), *args)
          {{klass}}.new(_query, *args).call
        end

        def self.{{name.id}}(*args)
          {{name.id}}(all, *args)
        end
      end
    end
  end
end
