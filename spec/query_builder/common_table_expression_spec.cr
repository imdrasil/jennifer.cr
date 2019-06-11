require "../spec_helper"

describe Jennifer::QueryBuilder::CommonTableExpression do
  described_class = Jennifer::QueryBuilder::CommonTableExpression

  describe "#filterable?" do
    it "delegates call to query" do
      described_class.new("cte", Jennifer::Query["contacts"].where { _age == 2 }, true).filterable?.should be_true
      described_class.new("cte", Jennifer::Query["contacts"].where { _main }, true).filterable?.should be_false
    end
  end

  describe "#sql_args" do
    it "delegates call to query" do
      described_class.new("cte", Jennifer::Query["contacts"].where { _age == 2 }, true).sql_args.should eq(db_array(2))
      described_class.new("cte", Jennifer::Query["contacts"].where { _main }, true).sql_args.should be_empty
    end
  end
end
