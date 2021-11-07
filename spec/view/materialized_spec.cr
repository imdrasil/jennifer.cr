require "../spec_helper"
postgres_only do
  describe Jennifer::View::Materialized do
    describe ".refresh" do
      it "refreshes view" do
        Factory.create_contact(gender: "female")
        FemaleContact.all.count.should eq(0)
        FemaleContact.refresh
        FemaleContact.all.count.should eq(1)
      end
    end

    context "COLUMNS_METADATA" do
      it "includes all fields" do
        FemaleContact::COLUMNS_METADATA.keys.to_a.should eq([:id, :name])
      end
    end
  end
end
