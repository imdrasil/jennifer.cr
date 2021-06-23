require "../spec_helper"

postgres_only do
  describe Jennifer::Model::PgEnumConverter do
    it "loads field from the database" do
      record = Factory.create_contact(gender: "female").reload
      record.gender.should be_a(String)
      record.gender.should eq("female")
    end

    it "saves changed field to the database" do
      record = Factory.create_contact(gender: "female")
      record.gender = "male"
      record.save
      record.reload.gender.should eq("male")
    end

    it "saves new record" do
      record = Factory.create_contact(gender: "female")
      record.gender.should eq("female")
    end

    it "is accepted by hash constructor" do
      record = Contact.new({"gender" => "female", "name" => "Sam"})
      record.gender.should eq("female")
    end

    describe ".from_hash" do
      it "accepts bytes value" do
        Jennifer::Model::PgEnumConverter.from_hash({"value" => "female".to_slice}, "value", {name: "value"}).should eq("female")
      end
    end
  end
end
