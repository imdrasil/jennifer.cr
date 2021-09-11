require "../spec_helper"

describe Jennifer::QueryBuilder::Star do
  described_class = Jennifer::QueryBuilder::Star

  describe "#identifier" do
    it "adds star" do
      described_class.new("table").identifier.should eq(%(#{quote_identifier("table")}.*))
    end
  end
end
