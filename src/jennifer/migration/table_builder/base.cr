module Jennifer
  module Migration
    module TableBuilder
      abstract class Base
        # Base allowed types for migration DSL option values
        alias AllowedTypes = String | Int32 | Bool | Float32 | Float64 | JSON::Any | Nil
        # Allowed types for migration DSL + Symbol
        alias EAllowedTypes = AllowedTypes | Symbol
        # Allowed types for migration DSL including array
        alias AAllowedTypes = EAllowedTypes | Array(EAllowedTypes)
        # Hash type for options argument
        alias DB_OPTIONS = Hash(Symbol, EAllowedTypes | Array(EAllowedTypes))

        delegate schema_processor, table_exists?, index_exists?, column_exists?, to: adapter

        getter adapter : Adapter::Base, name : String

        def initialize(@adapter, name : String | Symbol)
          @name = name.to_s
          @commands = [] of Base
        end

        abstract def process

        def process_commands
          @commands.each(&.process)
        end

        def to_s
          "#{@name} -> #{self.class.to_s}"
        end
      end
    end
  end
end
