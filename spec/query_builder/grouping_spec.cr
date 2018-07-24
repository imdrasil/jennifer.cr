require "../spec_helper"

describe Jennifer::QueryBuilder::Grouping do
  described_class = Jennifer::QueryBuilder::Grouping
  c1 = Factory.build_criteria
  c2 = Factory.build_criteria == 2

  describe "#as_sql" do
    it "wrap sql with parenthesis" do
      g = described_class.new(c1 & c2)
      g.as_sql.should match(/\(tests\.f1 AND tests\.f1 = %s\)/)
    end
  end

  describe "#sql_args" do
    it "returns arguments from nested query" do
      g = described_class.new(c1 & c2)
      g.sql_args.should eq([2])
    end
  end

  describe "#filterable?" do
    it { described_class.new(c1 & c1).filterable?.should be_false }
    it { described_class.new(c1 & c2).filterable?.should be_true }
  end
end
