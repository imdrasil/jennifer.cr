module Jennifer
  module Migration
    module TableBuilder
      abstract class Base
        # Base allowed types for migration DSL option values.
        alias AllowedTypes = String | Int32 | Int64 | Bool | Float32 | Float64 | JSON::Any | Nil

        # Allowed types for migration DSL + Symbol.
        alias EAllowedTypes = AllowedTypes | Symbol

        # Allowed types for migration DSL including array of itself.
        alias AAllowedTypes = EAllowedTypes | Array(EAllowedTypes)

        # Hash type for options argument
        alias DbOptions = Hash(Symbol, EAllowedTypes | Array(EAllowedTypes))

        # Default ON UPDATE/ON DELETE for foreign key.
        DEFAULT_ON_EVENT_ACTION = :restrict

        delegate schema_processor, table_exists?, index_exists?, column_exists?, to: adapter

        getter adapter : Adapter::Base, name : String

        def initialize(@adapter, name : String | Symbol)
          @name = name.to_s
          @commands = [] of Base
        end

        # Invokes current command.
        abstract def process

        # Returns string presentation of invoked changes.
        abstract def explain

        # Invokes underlying commands.
        def process_commands
          @commands.each(&.process)
        end

        private def build_column_options(type : Symbol?, options : Hash)
          if type.nil? && !options.has_key?(:sql_type)
            raise ArgumentError.new("Both type and sql_type can't be blank")
          end

          Ifrit.sym_hash_cast(options, AAllowedTypes).merge({:type => type} of Symbol => AAllowedTypes)
        end
      end
    end
  end
end
