require "../spec_helper"

mysql_only do
  describe Jennifer::Mysql::Adapter do
    adapter = Jennifer::Adapter.default_adapter.as(Jennifer::Mysql::Adapter)

    describe "#index_exists?" do
      it "returns true if table has index with given name" do
        adapter.index_exists?("contacts", "contacts_description_idx").should be_true
      end

      it "returns true if table has index with given columns" do
        adapter.index_exists?("contacts", [:description]).should be_true
      end

      it "returns false if table has no given index" do
        adapter.index_exists?("addresses", "contacts_description_id_idx").should be_false
      end
    end

    describe "#translate_type" do
      it "returns SQL type associated with given synonim" do
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

    describe "#explain" do
      it "has header" do
        explanation = adapter.explain(Query["contacts"]).split("\n")

        explanation[0].split("|").map(&.strip).should eq(%w(id select_type table partitions type possible_keys key key_len ref rows filtered Extra))
      end

      it "includes row data" do
        explanation = adapter.explain(Query["contacts"]).split("\n")
        cols = explanation[2].split("|").map(&.strip)
        cols[0..8].should eq(%w(1 SIMPLE contacts NULL ALL NULL NULL NULL NULL))
        cols[9].should match(/\d*/)
        cols[10].should eq("100.0")
        cols[11].should eq("NULL")
      end
    end
  end
end
