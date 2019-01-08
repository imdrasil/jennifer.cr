require "../../spec_helper"

mysql_only do
  describe Jennifer::Mysql::SchemaProcessor do
    adapter = Jennifer::Adapter.adapter
    processor = adapter.schema_processor

    describe "#rename_table" do
      it do
        match_query_from_exception(/ALTER TABLE old_name RENAME new_name/) do
          processor.rename_table("old_name", "new_name")
        end
      end
    end
  end
end