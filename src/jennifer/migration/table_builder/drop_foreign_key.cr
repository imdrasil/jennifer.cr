module Jennifer
  module Migration
    module TableBuilder
      class DropForeignKey < Base
        getter from_table : String, to_table : String

        def initialize(adapter, @from_table, @to_table, column, name)
          column_name = CreateForeignKey.column_name(@to_table, column)
          super(adapter, CreateForeignKey.foreign_key_name(@from_table, column_name, name))
        end

        def process
          schema_processor.drop_foreign_key(from_table, name)
        end
      end
    end
  end
end
