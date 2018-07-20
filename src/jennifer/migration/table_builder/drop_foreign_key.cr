module Jennifer
  module Migration
    module TableBuilder
      class DropForeignKey < Base
        getter from_table : String, to_table : String

        def initialize(adapter, @from_table, @to_table, name)
          super(adapter, (name || adapter.class.foreign_key_name(@from_table, @to_table)).to_s)
        end

        def process
          schema_processor.drop_foreign_key(from_table, name)
        end
      end
    end
  end
end
