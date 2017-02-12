module Jennifer
  module Migration
    module TableBuilder
      abstract class Base
        include Support

        getter fields, name

        alias AllowedTypes = String | Int32 | Bool | Float32
        alias EAllowedTypes = AllowedTypes | Symbol
        alias DB_OPTIONS = Hash(Symbol, AllowedTypes | Symbol)

        def initialize(@name : String | Symbol)
          @fields = {} of String => DB_OPTIONS
        end

        abstract def process

        def to_s
          "#{@name} -> #{self.class.to_s}"
        end
      end
    end
  end
end
