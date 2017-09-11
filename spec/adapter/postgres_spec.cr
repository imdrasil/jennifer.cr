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

    describe "#material_view_exists?" do
      it "returns true if exists" do
        adapter.material_view_exists?("female_contacts").should be_true
      end

      it "returns false if doen't exist" do
        adapter.material_view_exists?("male_contacts").should be_false
      end
    end

    describe "#table_column_count" do
      context "given a materialized view name" do
        it "returns count of materialized view fields" do
          adapter.table_column_count("female_contacts").should eq(9)
        end
      end

      context "given table name" do
        it "returns amount of table fields" do
          adapter.table_column_count("addresses").should eq(5)
        end
      end

      it "returns -1 if name is not a table or MV" do
        adapter.table_column_count("asdasd").should eq(-1)
      end
    end

    describe "#refresh_materialized_view" do
      it "refreshes data on given MV" do
        Factory.create_contact(gender: "female")
        Factory.create_contact(gender: "male")
        FemaleContact.all.count.should eq(0)
        adapter.refresh_materialized_view(FemaleContact.table_name)
        FemaleContact.all.count.should eq(1)
      end
    end
  end
end
