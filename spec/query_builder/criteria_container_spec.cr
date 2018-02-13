require "../spec_helper"

describe Jennifer::QueryBuilder::CriteriaContainer do
  described_class = Jennifer::QueryBuilder::CriteriaContainer

  container = described_class.new
  container[Factory.build_criteria(field: "a1")] = "desc"
  container[Factory.build_criteria(field: "a2")] = "asc"

  describe "#each" do
    it "iterates over all contained elements" do
      size = 0
      container.each do |criteria, order|
        criteria.should be_a(Jennifer::QueryBuilder::Criteria)
        order.should be_a(String)
        size += 1
      end
      size.should eq(2)
    end
  end

  describe "#keys" do
    it do
      container.keys[0].field.should eq("a1")
      container.keys[1].field.should eq("a2")
    end
  end

  describe "#values" do
    it do
      container.values[0].should eq("desc")
      container.values[1].should eq("asc")
    end
  end

  describe "#[]=" do
    it do
      cont = described_class.new

      cont[Factory.build_criteria] = "desc"
      cont.empty?.should be_false
    end
  end

  describe "#[]" do
    it do
      container[Factory.build_criteria(field: "a1")].should eq("desc")
    end

    it do
      expect_raises(KeyError) do
        container[Factory.build_criteria(field: "a3")]
      end
    end
  end

  describe "[]?" do
    it do
      container[Factory.build_criteria(field: "a1")]?.should eq("desc")
    end

    it do
      container[Factory.build_criteria(field: "a3")]?.should be_nil
    end
  end

  describe "#clear" do
    it do
      cont = described_class.new
      cont[Factory.build_criteria(field: "a1")] = "desc"
      cont.empty?.should be_false
      cont.clear
      cont.empty?.should be_true
    end
  end

  describe "#empty?" do
    it do
      cont = described_class.new
      cont.empty?.should be_true
      cont[Factory.build_criteria(field: "a1")] = "desc"
      cont.empty?.should be_false
    end
  end

  describe "#size" do
    it { container.size.should eq(2) }
  end

  describe "#delete" do
    it do
      cont = described_class.new
      
      cont[Factory.build_criteria(field: "a1")] = "desc"
      cont[Factory.build_criteria(field: "a2")] = "asc"

      cont.delete(Factory.build_criteria(field: "a2"))

      cont[Factory.build_criteria(field: "a1")].should eq("desc")
      cont.size.should eq(1)
    end
  end
end
