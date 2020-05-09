require "./spec_helper"

def drop_table_expr
  Jennifer::Migration::TableBuilder::DropTable.new(Jennifer::Adapter.default_adapter, DEFAULT_TABLE)
end

describe Jennifer::Migration::TableBuilder::DropTable do
  describe "#process" do
    pending "add" do
    end
  end
end
