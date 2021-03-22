require "../spec_helper"

describe Jennifer::QueryBuilder::Aggregations do
  described_class = Jennifer::QueryBuilder::Query

  describe "#count" do
    it "returns count of rows for given query" do
      Factory.create_contact(name: "Asd")
      Factory.create_contact(name: "BBB")
      described_class.new("contacts").where { _name.like("%A%") }.count.should eq(1)
    end
  end

  describe "#max" do
    it "returns maximum value" do
      Factory.create_contact(name: "Asd")
      Factory.create_contact(name: "BBB")
      described_class.new("contacts").max(:name, String).should eq("BBB")
    end
  end

  describe "#min" do
    it "returns minimum value" do
      Factory.create_contact(name: "Asd", age: 19)
      Factory.create_contact(name: "BBB", age: 20)
      described_class.new("contacts").min(:age, Int32).should eq(19)
    end
  end

  describe "#sum" do
    it "returns sum value" do
      Factory.create_contact(name: "Asd", age: 20)
      Factory.create_contact(name: "BBB", age: 19)
      {% if env("DB") == "mysql" %}
        described_class.new("contacts").sum(:age, Float64).should eq(39)
      {% else %}
        described_class.new("contacts").sum(:age, Int64).should eq(39i64)
      {% end %}
    end
  end

  describe "#avg" do
    it "returns average value" do
      Factory.create_contact(name: "Asd", age: 20)
      Factory.create_contact(name: "BBB", age: 35)
      {% if env("DB") == "mysql" %}
        described_class.new("contacts").avg(:age, Float64).should eq(27.5)
      {% else %}
        described_class.new("contacts").avg(:age, PG::Numeric).should eq(27.5)
      {% end %}
    end
  end

  describe "#group_max" do
    it "returns array of maximum values" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 19)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      Factory.create_contact(name: "BBB", gender: "female", age: 21)
      described_class.new("contacts").group(:gender).group_max(:age, Int32).should match_array([20, 21])
    end
  end

  describe "#group_min" do
    it "returns minimum value" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 19)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      Factory.create_contact(name: "BBB", gender: "female", age: 21)
      described_class.new("contacts").group(:gender).group_min(:age, Int32).should match_array([18, 19])
    end
  end

  describe "#group_sum" do
    it "returns sum value" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 19)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      Factory.create_contact(name: "BBB", gender: "female", age: 21)
      {% if env("DB") == "mysql" %}
        described_class.new("contacts").group(:gender).group_sum(:age, Float64).should match_array([38.0, 40.0])
      {% else %}
        described_class.new("contacts").group(:gender).group_sum(:age, Int64).should match_array([38i64, 40i64])
      {% end %}
    end
  end

  describe "#group_avg" do
    it "returns average value" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 19)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      Factory.create_contact(name: "BBB", gender: "female", age: 21)
      klass = {% if env("DB") == "mysql" %} Float64 {% else %} PG::Numeric {% end %}
      [19.0, 20.0].should match_array(described_class.new("contacts").group(:gender).group_avg(:age, klass).map(&.to_f))
    end
  end

  describe "#group_count" do
    it "returns count of each group elements" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 18)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      [2, 1].should match_array(described_class.new("contacts").group(:age).group_count(:age))
    end
  end
end
