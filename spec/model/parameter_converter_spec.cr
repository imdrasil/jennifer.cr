require "../spec_helper"

describe Jennifer::Model::ParameterConverter do
  converter = Jennifer::Model::ParameterConverter.new

  describe "#parse" do
    it { converter.parse("1", "String?").is_a?(String).should be_true }
    it { converter.parse("1", "Int16").is_a?(Int16).should be_true }
    it { converter.parse("1", "Int32").is_a?(Int32).should be_true }
    it { converter.parse("1", "Int64").is_a?(Int64).should be_true }
    it { converter.parse("1", "Float64").is_a?(Float64).should be_true }
    it { converter.parse("1", "Float32?").class.should eq(Float32) }
    it { converter.parse("1", "Bool").is_a?(Bool).should be_true }
    it { converter.parse("1", "JSON::Any?").is_a?(JSON::Any).should be_true }
    it { converter.parse("2010-12-10", "Time?").is_a?(Time).should be_true }
    postgres_only do
      it { converter.parse("1", "Numeric?").is_a?(PG::Numeric).should be_true }
    end
    it { converter.parse(%(["1"]), "Array(String)").class.should eq(Array(String)) }
    it { converter.parse("asd".as(String?), "String?").class.should eq(String) }
    it { converter.parse(nil.as(String?), "String?").class.should eq(Nil) }
  end

  postgres_only do
    describe "#to_numeric" do
      it { converter.to_numeric("1").to_s.should eq("1") }
      it { converter.to_numeric("12345").to_s.should eq("12345") }
      it { converter.to_numeric("9999").to_s.should eq("9999") }
      it { converter.to_numeric("-1").to_s.should eq("-1") }
      it { converter.to_numeric("1.12345").to_s.should eq("1.12345") }
      it { converter.to_numeric("-1.12345").to_s.should eq("-1.12345") }

      # NOTE: some cases from the will/crystal-pg

      it { converter.to_numeric("0").to_s.should eq("0") }
      it { converter.to_numeric("0.0").to_s.should eq("0.0") }
      it { converter.to_numeric("1.30").to_s.should eq("1.30") }
      it { converter.to_numeric("-0.00009").to_s.should eq("-0.00009") }
      it { converter.to_numeric("-0.00000009").to_s.should eq("-0.00000009") }
      it { converter.to_numeric("50093").to_s.should eq("50093") }
      it { converter.to_numeric("500000093").to_s.should eq("500000093") }
      it { converter.to_numeric("0.0000006000000").to_s.should eq("0.0000006000000") }
      it { converter.to_numeric("0.3").to_s.should eq("0.3") }
      it { converter.to_numeric("0.03").to_s.should eq("0.03") }
      it { converter.to_numeric("0.003").to_s.should eq("0.003") }
      it { converter.to_numeric("0.000300003").to_s.should eq("0.000300003") }
    end
  end

  describe "#to_time" do
    it { converter.to_time("2010-10-10").should eq(Time.new(2010, 10, 10)) }
    it { converter.to_time("2010-10-10 20:10:10").should eq(Time.new(2010, 10, 10, 20, 10, 10)) }
    it "ignores given time zone" do
      converter.to_time("2010-10-10 20:10:10 +01:00").should eq(Time.new(2010, 10, 10, 20, 10, 10, location: local_time_zone))
    end
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
