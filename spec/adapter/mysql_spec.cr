require "../spec_helper"

mysql_only do
  describe Jennifer::Mysql::Adapter do
    described_class = Jennifer::Mysql::Adapter
    adapter = Jennifer::Adapter.adapter.as(Jennifer::Mysql::Adapter)

    describe "#index_exists?" do
      it "returns true if table has index with given name" do
        adapter.index_exists?("contacts", "contacts_description_index").should be_true
      end

      it "returns false if table has no given index" do
        adapter.index_exists?("addresses", "contacts_description_index").should be_false
      end
    end

    describe "#translate_type" do
      it "returns sql type associated with given synonim" do
        adapter.translate_type(:string).should eq("varchar")
      end
    end

    describe "#default_type_size" do
      it "returns default type size for given alias" do
        adapter.default_type_size(:string).should eq(254)
      end
    end

    describe "#parse_query" do
      it "returns string without %s placeholders" do
        adapter.parse_query("asd %s asd", [2] of Jennifer::DBAny).should eq({"asd ? asd", [2]})
      end
    end
  end
end
