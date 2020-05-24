require "../spec_helper"

describe Jennifer::QueryBuilder::RawSql do
  described_class = Jennifer::QueryBuilder::RawSql

  describe "#initialize" do
    context "with % in raw SQL" do
      it "raises AmbiguousSQL exception" do
        expect_raises(Jennifer::AmbiguousSQL) do
          described_class.new("field LIKE '%asd'")
        end
      end
    end
  end

  describe "#identifier" do
    context "with brackets" do
      it "puts brackets by default" do
        described_class.new("some sql").identifier.should eq("(some sql)")
      end
    end

    context "without brackets" do
      it "puts raw SQL content if object is marked to be without brackets" do
        described_class.new("some sql", false).identifier.should eq("some sql")
      end
    end
  end

  describe "#sql_args" do
    it "returns given argument array" do
      args = described_class.new("age > %s", [12]).sql_args
      args.should eq(db_array(12))
    end
  end

  describe "#filterable?" do
    it { described_class.new("sql", [1]).filterable?.should be_true }
    it { described_class.new("sql").filterable?.should be_false }
  end
end
