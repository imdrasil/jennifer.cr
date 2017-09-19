module Jennifer
  module Migration
    module TableBuilder
      abstract class Base
        alias AllowedTypes = String | Int32 | Bool | Float32 | Nil
        alias EAllowedTypes = AllowedTypes | Symbol
        alias AAllowedTypes = EAllowedTypes | Array(EAllowedTypes)
        alias HAllowedTypes = EAllowedTypes | Array(EAllowedTypes) | Hash(Symbol, EAllowedTypes | Array(EAllowedTypes)) | Hash(Symbol, EAllowedTypes)
        alias DB_OPTIONS = Hash(Symbol, EAllowedTypes | Array(EAllowedTypes))

        extend Ifrit

        delegate table_exists?, index_exists?, column_exists?, to: Adapter.adapter

        getter fields

        @name : String | Symbol

        def initialize(@name)
          @fields = {} of String => DB_OPTIONS
          @indexes = {} of String => Hash(Symbol, HAllowedTypes)
        end

        def name
          @name.to_s
        end

        abstract def process

        def to_s
          "#{@name} -> #{self.class.to_s}"
        end
      end
    end
  end
end
