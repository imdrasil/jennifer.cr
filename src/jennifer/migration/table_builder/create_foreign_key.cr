module Jennifer
  module Migration
    module TableBuilder
      class CreateForeignKey < Base
        getter from_table : String, to_table : String, column : String, primary_key : String

        def initialize(adapter, @from_table, @to_table, column, primary_key, name)
          @column = (column || Inflector.foreign_key(Inflector.singularize(@to_table))).to_s
          @primary_key = (primary_key || "id").to_s
          super(adapter, (name || adapter.class.foreign_key_name(@from_table, @to_table)).to_s)
        end

        def process
          schema_processor.add_foreign_key(from_table, to_table, column, primary_key, name)
        end
      end
    end
  end
end
