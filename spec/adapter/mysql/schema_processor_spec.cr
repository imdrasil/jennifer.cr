require "../../spec_helper"

mysql_only do
  describe Jennifer::Mysql::SchemaProcessor do
    adapter = Jennifer::Adapter.default_adapter
    processor = adapter.schema_processor

    describe "#rename_table" do
      it do
        match_query_from_exception(/ALTER TABLE old_name RENAME new_name/) do
          processor.rename_table("old_name", "new_name")
        end
      end
    end

    describe "#drop_foreign_key" do
      it do
        match_query_from_exception(/ALTER TABLE table_name DROP FOREIGN KEY key_name/) do
          processor.drop_foreign_key("table_name", "to_table", "key_name")
        end
      end
    end
  end
end
