require "./spec_helper"

def create_view_expr
  Jennifer::Migration::TableBuilder::CreateView.new(Jennifer::Adapter.default_adapter, DEFAULT_TABLE)
end

describe Jennifer::Migration::TableBuilder::CreateView do
  describe "#process" do
    pending "add" do
    end
  end
end
