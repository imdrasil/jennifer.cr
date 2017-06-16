require "../spec_helper"

postgres_only do
  describe Jennifer::Adapter::Postgres do
    adapter = Jennifer::Adapter.adapter
    describe "#parse_query" do
      it "replaces %s by dollar-and-numbers" do
        adapter.parse_query("some %s query %s", ["a", "b"]).should eq("some $1 query $2")
      end
    end

    describe "#add_index" do
      # tested via adding index in migration
      pending "add" do
      end
    end

    describe "#change_column" do
    end

    # Now those methods are tested by another cases
    describe "#exists?" do
    end

    describe "#insert" do
    end

    describe "#index_exists?" do
      it "returns true if exists index with given name" do
        adapter.index_exists?("", "contacts_description_index").should be_true
      end

      it "returns false if index is not exist" do
        adapter.index_exists?("", "contacts_description_index_test").should be_false
      end
    end
  end
end
