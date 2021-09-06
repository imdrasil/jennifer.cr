require "../spec_helper"

postgres_only do
  describe Jennifer::Model::NumericToFloat64Converter do
    described_class = Jennifer::Model::NumericToFloat64Converter

    it "loads field from the database" do
      ballance = PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [3i16])
      id = Factory.create_contact(ballance: ballance).id
      record = ContactWithFloatMapping.all.find!(id)
      record.ballance.should be_a(Float64)
      record.ballance.should eq(3.0)
    end

    it "saves changed field to the database" do
      ballance = PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [3i16])
      id = Factory.create_contact(ballance: ballance).id
      record = ContactWithFloatMapping.all.find!(id)
      record.ballance = 1.1
      record.save
      record.reload.ballance.should eq(1.1)
    end

    it "saves new record" do
      record = ContactWithFloatMapping.create({ballance: 32.05})
      record.reload.ballance.should eq(32.05)
    end

    it "is accepted by hash constructor" do
      record = ContactWithFloatMapping.create({"ballance" => 32.05})
      record.reload.ballance.should eq(32.05)
    end

    describe ".from_hash" do
      it "accepts PG::Numeric" do
        value = PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [3i16])
        described_class.from_hash({"value" => value}, "value", {name: "value"}).should eq(3.0)
      end

      it "accepts string" do
        described_class.from_hash({"value" => "3.01"}, "value", {name: "value"}).should eq(3.01)
      end

      it "accepts int" do
        described_class.from_hash({"value" => 2}, "value", {name: "value"}).should eq(2.0)
      end
    end
  end
end
