require "../spec_helper"

describe Jennifer::Model::ParameterConverter do
  converter = Jennifer::Model::ParameterConverter.new

  describe "#parse" do
    it { converter.parse("1", "String?").is_a?(String).should be_true }
    it { converter.parse("1", "Int16").is_a?(Int16).should be_true }
    it { converter.parse("1", "Int32").is_a?(Int32).should be_true }
    it { converter.parse("1", "Primary32").is_a?(Int32).should be_true }
    it { converter.parse("1", "Primary64").is_a?(Int64).should be_true }
    it { converter.parse("1", "Float64").is_a?(Float64).should be_true }
    it { converter.parse("1", "Float32?").class.should eq(Float32) }
    it { converter.parse("1", "Bool").is_a?(Bool).should be_true }
    it { converter.parse("1", "JSON::Any?").is_a?(JSON::Any).should be_true }
    it { converter.parse("2010-12-10", "Time?").is_a?(Time).should be_true }
    it { converter.parse("1", "Numeric?").is_a?(PG::Numeric).should be_true }
    it { converter.parse(%(["1"]), "Array(String)").class.should eq(Array(String)) }
  end

  postgres_only do
    describe "#to_numeric" do
      it { converter.to_numeric("1").to_s.should eq("1") }
      it { converter.to_numeric("12345").to_s.should eq("12345") }
      it { converter.to_numeric("9999").to_s.should eq("9999") }
      it { converter.to_numeric("-1").to_s.should eq("-1") }
      it { converter.to_numeric("1.12345").to_s.should eq("1.12345") }
      it { converter.to_numeric("-1.12345").to_s.should eq("-1.12345") }
    end
  end

  describe "#to_time" do
    it { converter.to_time("2010-10-10").should eq(Time.new(2010, 10, 10)) }
    it { converter.to_time("2010-10-10 20:10:10").should eq(Time.new(2010, 10, 10, 20, 10, 10)) }
  end

  describe "#to_b" do
    it { converter.to_b("1").should be_true }
    it { converter.to_b("true").should be_true }
    it { converter.to_b("t").should be_true }
    it { converter.to_b("0").should be_false }
    it { converter.to_b("").should be_false }
  end

  describe "#to_array" do
    it { converter.to_array("[1]", "Array(Int32)").should eq([1]) }
    it { converter.to_array("[1]", "Array(Int16)").should eq([1i16]) }
    it { converter.to_array("[1]", "Array(Int64)").should eq([1i64]) }
    it { converter.to_array(%(["1"]), "Array(String)").should eq(["1"]) }
    it { converter.to_array("[1.0]", "Array(Float32)").should eq([1f32]) }
    it { converter.to_array("[1.0]", "Array(Float64)").should eq([1.0]) }
  end
end
