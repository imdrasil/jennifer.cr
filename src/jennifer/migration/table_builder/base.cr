module Jennifer
  module Migration
    module TableBuilder
      abstract class Base
        alias AllowedTypes = String | Int32 | Bool | Float32 | Nil
        alias EAllowedTypes = AllowedTypes | Symbol
        alias AAllowedTypes = EAllowedTypes | Array(EAllowedTypes)
        alias DB_OPTIONS = Hash(Symbol, EAllowedTypes | Array(EAllowedTypes))

        extend Ifrit

        delegate schema_processor, table_exists?, index_exists?, column_exists?, to: adapter

        getter adapter : Adapter::Base

        @name : String

        def initialize(@adapter, name : String | Symbol)
          @name = name.to_s
          @commands = [] of Base
        end

        def name
          @name.to_s
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
