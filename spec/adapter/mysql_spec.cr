require "../spec_helper"
mysql_only do
  describe Jennifer::Adapter::Mysql do
    adapter = Jennifer::Adapter.adapter
    describe "#index_exists?" do
      it "returns true if table has index with given name" do
        adapter.index_exists?("contacts", "contacts_description_index").should be_true
      end

      it "returns false if table has no given index" do
        adapter.index_exists?("addresses", "contacts_description_index").should be_false
      end
    end
  end
end
