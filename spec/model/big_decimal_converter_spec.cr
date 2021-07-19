require "../spec_helper"

describe Jennifer::Model::BigDecimalConverter do
  described_class = Jennifer::Model::BigDecimalConverter(PG::Numeric)

  describe ".from_db" do
    postgres_only do
      it "reads numeric from result set" do
        ballance = PG::Numeric.new(2i16, 0i16, 0i16, 3i16, [1234i16, 6800i16])
        executed = false
        Factory.create_contact(ballance: ballance)
        Contact.all.select([Contact._ballance]).each_result_set do |rs|
          described_class.from_db(rs, {name: "ballance", scale: 2, null: false}).should eq(BigDecimal.new(123468, 2))
          executed = true
        end
        executed.should be_true
      end
    end

    it "reads nil from result set" do
      executed = false
      Factory.create_contact(ballance: nil)
      Contact.all.select([Contact._ballance]).each_result_set do |rs|
        described_class.from_db(rs, {name: "ballance", scale: 2, null: true}).should be_nil
        executed = true
      end
      executed.should be_true
    end
  end

  describe ".to_db" do
    postgres_only do
      it "writes value to a result set" do
        balance = described_class.to_db(BigDecimal.new(123468, 2), {name: "ballance", scale: 2})
        Query["contacts"].insert(%w(name age ballance), [["test", 1, balance]])
        Contact.all.last!.ballance.should eq(PG::Numeric.new(2i16, 0i16, 0i16, 2i16, [1234i16, 6800i16]))
      end
    end
  end

  describe ".from_hash" do
    postgres_only do
      it "converts numeric" do
        balance = PG::Numeric.new(2i16, 0i16, 0i16, 2i16, [1234i16, 6800i16])
        described_class.from_hash({"ballance" => balance}, "ballance", {name: "ballance", scale: 2})
          .should eq(BigDecimal.new(123468, 2))
      end
    end

    it "accepts nil value" do
      described_class.from_hash({"ballance" => nil}, "ballance", {name: "ballance", scale: 2}).should be_nil
    end

    it "accepts string value" do
      described_class.from_hash({"ballance" => "12.123"}, "ballance", {name: "ballance", scale: 2})
        .should eq(BigDecimal.new(12123, 3))
    end

    it "accepts int value" do
      described_class.from_hash({"ballance" => 12}, "ballance", {name: "ballance", scale: 2})
        .should eq(BigDecimal.new(1200, 2))
    end

    it "accepts float value" do
      described_class.from_hash({"ballance" => 12.123}, "ballance", {name: "ballance", scale: 2})
        .should eq(BigDecimal.new(1212, 2))
    end
  end

  describe ".coerce" do
    it { described_class.coerce("123.12", {scale: 2}).should eq(BigDecimal.new(12312, 2)) }
    it { described_class.coerce("", {scale: 2}).should be_nil }
  end
end
