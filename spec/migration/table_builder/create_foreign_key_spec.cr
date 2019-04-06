require "./spec_helper"

describe Jennifer::Migration::TableBuilder::CreateForeignKey do
  described_class = Jennifer::Migration::TableBuilder::CreateForeignKey
  adapter = Jennifer::Adapter.adapter

  describe ".new" do
    context "with nil value of column" do
      it do
        command = described_class.new(adapter, DEFAULT_TABLE, "to_tables", nil, "primary", "name")
        command.primary_key.should eq("primary")
        command.name.should eq("name")
        command.column.should eq("to_table_id")
      end
    end

    context "with nil value of primary_key" do
      it do
        command = described_class.new(adapter, DEFAULT_TABLE, "to_tables", "column", nil, "name")
        command.primary_key.should eq("id")
        command.name.should eq("name")
        command.column.should eq("column")
      end
    end

    context "with nil value of name" do
      it do
        command = described_class.new(adapter, DEFAULT_TABLE, "to_tables", "column", "primary", nil)
        command.primary_key.should eq("primary")
        command.name.should eq("fk_cr_81338c9f68")
        command.column.should eq("column")
      end
    end
  end

  describe "#process" do
    pending "add" do
    end
  end

  describe ".foreign_key_name" do
    context "with name" do
      it { described_class.foreign_key_name("table", "column", "name").should eq("name") }
    end

    it { described_class.foreign_key_name("accounts", "branch_id", nil).should eq("fk_cr_d72169e1fc") }
  end

  describe ".column_name" do
    context "with present column name" do
      it { described_class.column_name("table", "name").should eq("name") }
    end
  end
end
