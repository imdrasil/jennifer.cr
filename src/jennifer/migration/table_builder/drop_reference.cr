require "./drop_foreign_key"

module Jennifer::Migration::TableBuilder
  class DropReference < Base
    def initialize(adapter, from_table, to_table, column, name = nil)
      super(adapter, from_table)
      @commands << DropForeignKey.new(adapter, from_table, to_table, column, name)
    end

    def process
      command.process
      schema_processor.drop_column(@name, command.as(DropForeignKey).column)
    end

    def explain
      command.explain
    end

    private def command
      @commands[0]
    end
  end
end
