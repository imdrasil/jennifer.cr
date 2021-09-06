module Jennifer
  module Model
    module Scoping
      # Adds a class method for retrieving and querying objects.
      #
      # A `.scope` presents a narrowing of a database query, such as
      # `where { _color == "red" }.includes(:washing_instructions)`.
      #
      # ```
      # class Shirt < Jennifer::Model::Base
      #   # ...
      #   scope :red { where { _color == "red" } }
      # end
      # ```
      macro scope(name, &block)
        {% underscored_arg_list = block.args.map(&.stringify).map { |e| "__" + e }.join(", ").id %}
        # :nodoc:
        class Jennifer::QueryBuilder::ModelQuery(T)
          def {{name.id}}({{ block.args.splat }})
            # NOTE: this is workaround for #responds_to?
            klass = T
            if klass.responds_to?(:{{name.id}})
              klass.{{name.id}}(self, {{block.args.splat}})
            else
              raise Jennifer::BaseException.new("#{T} class has no {{name.id}} scope.")
            end
          end
        end

        def self.{{name.id}}({{ underscored_arg_list }})
          {{name.id}}(all{% if !block.args.empty? %}, {{underscored_arg_list}} {% end %})
        end

        # :nodoc:
        def self.{{name.id}}(_query : ::Jennifer::QueryBuilder::ModelQuery({{@type}}){% if !block.args.empty? %}, {{ underscored_arg_list }} {% end %})
          {% if !block.args.empty? %}
            {{ block.args.splat }} = {{underscored_arg_list}}
          {% end %}
          _query.exec { {{block.body}} }
        end
      end

      # Adds a class method for retrieving and querying objects.
      #
      # A `.scope` presents a narrowing of a database query, such as `where { _color == "red" }.includes(:washing_instructions)`.
      #
      # ```
      # class Shirt < Jennifer::Model::Base
      #   # ...
      #   scope :red, {where { _color == "red" }}
      # end
      # ```
      macro scope(name, klass)
        # :nodoc:
        class Jennifer::QueryBuilder::ModelQuery(T)
          def {{name.id}}(*args)
            klass = T
            if klass.responds_to?(:{{name.id}})
              klass.{{name.id}}(self, *args)
            else
              raise Jennifer::BaseException.new("#{T} class has no {{name.id}} scope.")
            end
          end
        end

        # :nodoc:
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
