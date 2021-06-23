require "../spec_helper"

alias DBOption = Jennifer::Migration::TableBuilder::Base::EAllowedTypes | Array(Jennifer::Migration::TableBuilder::Base::EAllowedTypes)

describe Jennifer::Adapter::SchemaProcessor do
  adapter = Jennifer::Adapter.default_adapter
  processor = adapter.schema_processor

  describe "#add_index" do
    it do
      match_query_from_exception(/CREATE INDEX index_name ON table_name \(field1,field2\)/) do
        processor.add_index("table_name", "index_name", ["field1", "field2"])
      end
    end

    pending "test types"
  end

  describe "#drop_index" do
    it do
      match_query_from_exception(/DROP INDEX index_name/) do
        processor.drop_index("table_name", "index_name")
      end
    end
  end

  describe "#drop_column" do
    it do
      match_query_from_exception(/ALTER TABLE table_name DROP COLUMN column/) do
        processor.drop_column("table_name", "column")
      end
    end
  end

  describe "#add_column" do
    it do
      match_query_from_exception(/ALTER TABLE table_name ADD COLUMN column int/) do
        processor.add_column("table_name", "column", {:type => :integer} of Symbol => DBOption)
      end
    end

    describe "serial" do
      it do
        match_query_from_exception(/ALTER TABLE table_name ADD COLUMN column serial/) do
          processor.add_column("table_name", "column", {:type => :integer, :serial => true} of Symbol => DBOption)
        end
      end
    end

    describe "primary key" do
      it do
        match_query_from_exception(/ALTER TABLE table_name ADD COLUMN column int PRIMARY KEY/) do
          processor.add_column("table_name", "column", {:type => :integer, :primary => true} of Symbol => DBOption)
        end
      end
    end

    describe "auto increment" do
      pending "add"
      # it do
      #   match_query_from_exception(/ALTER TABLE table_name ADD COLUMN column int AUTO_INCREMENT/) do
      #     processor.add_column("table_name", "column", { :type => :integer, :auto_increment => true } of Symbol => DBOption)
      #   end
      # end
    end

    context "with default" do
      it do
        match_query_from_exception(/ALTER TABLE table_name ADD COLUMN column int DEFAULT 10/) do
          processor.add_column("table_name", "column", {:type => :integer, :default => 10} of Symbol => DBOption)
        end
      end
    end

    describe "NULL" do
      context "with" do
        it do
          match_query_from_exception(/ALTER TABLE table_name ADD COLUMN column int NOT NULL/) do
            processor.add_column("table_name", "column", {:type => :integer, :null => false} of Symbol => DBOption)
          end
        end
      end

      context "without" do
        it do
          match_query_from_exception(/ALTER TABLE table_name ADD COLUMN column int NULL/) do
            processor.add_column("table_name", "column", {:type => :integer, :null => true} of Symbol => DBOption)
          end
        end
      end
    end

    describe "enum" do
      pending "add"
    end

    context "with custom size" do
      it do
        match_query_from_exception(/ALTER TABLE table_name ADD COLUMN column int\(2\)/) do
          processor.add_column("table_name", "column", {:type => :integer, :size => 2} of Symbol => DBOption)
        end
      end
    end

    context "with custom SQL type" do
      it do
        match_query_from_exception(/ALTER TABLE table_name ADD COLUMN column smallint/) do
          processor.add_column("table_name", "column", {:type => :integer, :sql_type => :smallint} of Symbol => DBOption)
        end
      end
    end
  end

  describe "#change_column" do
    pending "add"
  end

  describe "#drop_table" do
    it do
      match_query_from_exception(/DROP TABLE asd/) do
        builder = Jennifer::Migration::TableBuilder::DropTable.new(adapter, "asd")
        processor.drop_table(builder)
      end
    end
  end

  describe "#create_table" do
    pending "add"
  end

  describe "#create_view" do
    pending "add"
  end

  describe "#drop_view" do
    it do
      match_query_from_exception(/DROP VIEW view_name/) do
        processor.drop_view("view_name", false)
      end
    end

    context "with silent mode" do
      it "doesn't raise exception when view doesn't exist" do
        processor.drop_view("view_name", true)
      end
    end
  end

  describe "#add_foreign_key" do
    it do
      match_query_from_exception(/ALTER TABLE from_table ADD CONSTRAINT name FOREIGN KEY \(column\) REFERENCES to_table\(primary_key\) ON UPDATE RESTRICT ON DELETE NO ACTION/) do
        processor.add_foreign_key("from_table", "to_table", "column", "primary_key", "name", :restrict, :no_action)
      end
    end
  end
end
