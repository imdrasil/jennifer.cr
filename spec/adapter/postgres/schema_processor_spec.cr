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
    end
  end
end
