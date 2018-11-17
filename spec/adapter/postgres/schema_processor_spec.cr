require "../../spec_helper"

postgres_only do
  describe Jennifer::Postgres::SchemaProcessor do
    adapter = Jennifer::Adapter.adapter
    processor = adapter.schema_processor

    context "index manipulation" do
      index_name = "contacts_age_index"

      describe "#add_index" do
        it "should add a covering index if no type is specified" do
          processor.add_index("contacts", index_name, [:age])
          adapter.index_exists?("", index_name).should be_true
        end
      end

      describe "#drop_index" do
        it "should drop an index if it exists" do
          processor.add_index("contacts", index_name, [:age])
          adapter.index_exists?("", index_name).should be_true

          processor.drop_index("", index_name)
          adapter.index_exists?("", index_name).should be_false
        end
      end
    end

    describe "#change_column" do
      pending "add"
    end

    describe "#rename_table" do
      it do
        match_query_from_exception(/ALTER TABLE old_name RENAME TO new_name/) do
          processor.rename_table("old_name", "new_name")
        end
      end
    end
  end
end
