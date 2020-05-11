module Jennifer
  module Migration
    module TableBuilder
      class DropForeignKey < Base
        getter from_table : String, to_table : String, column : String

        def initialize(adapter, @from_table, @to_table, column, name)
          @column = CreateForeignKey.column_name(@to_table, column)
          super(adapter, CreateForeignKey.foreign_key_name(@from_table, @column, name))
        end

        def process
          schema_processor.drop_foreign_key(from_table, to_table, name)
        end

        def explain
          "drop_foreign_key :#{@from_table}, :#{@to_table}, :#{@column}, \"#{@name}\""
        end
      end
    end
  end
end
