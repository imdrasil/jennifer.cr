require "../spec_helper"

def get_record
  result = nil
  Factory.create_contact(name: "Jennifer", age: 20)
  Contact.all.each_result_set do |rs|
    result = Jennifer::Record.new(rs)
  end
  result.not_nil!
end

describe Jennifer::Record do
  described_class = Jennifer::Record

  describe "#initialize" do
    context "from hash" do
      it "loads without errors" do
        hash = {} of String => Jennifer::DBAny
        hash["name"] = "qweqwe"
        hash["age"] = 1
        described_class.new(hash)
      end
    end

    context "from result set" do
      it "properly loads all fields" do
        executed = false
        Factory.create_contact(name: "Jennifer", age: 20)
        Contact.all.each_result_set do |rs|
          record = described_class.new(rs)
          record.name.should eq("Jennifer")
          record.age.should eq(20)
          executed = true
        end
        executed.should be_true
      end
    end
  end

  describe "#/attribute_name/" do
    context "without type casting" do
      it "generates methods" do
        record = get_record
        record.name.should eq("Jennifer")
      end
    end

    context "with type casting" do
      it "generates method" do
        get_record.name(String).should eq("Jennifer")
      end
    end

    it "raises KeyError if no key is defined" do
      expect_raises(KeyError) do
        get_record.unknown_field
      end
    end
  end

  describe "#[]" do
    it "returns field by given key" do
      get_record["name"].should eq("Jennifer")
    end
  end

  describe "#attribute" do
    context "without typecasting" do
      it "returns value of any type" do
        value = get_record.attribute("name")
        value.should eq("Jennifer")
        typeof(value).should eq(Jennifer::DBAny)
      end
    end

    context "with typecasting" do
      it "returns value casted to the given type" do
        value = get_record.attribute("name", String)
        value.should eq("Jennifer")
        typeof(value).should eq(String)
      end
    end
  end
end
