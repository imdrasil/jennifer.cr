require "../spec_helper"

describe Jennifer::QueryBuilder::RawSql do
  described_class = Jennifer::QueryBuilder::RawSql

  describe "#identifier" do
    context "with brackets" do
      it "puts brackets by default" do
        described_class.new("some sql").identifier.should eq("(some sql)")
      end
    end

    context "without brackets" do
      it "puts raw sql content if object is marked to be without brackets" do
        described_class.new("some sql", false).identifier.should eq("some sql")
      end
    end
  end

  describe "#sql_params" do
    pending "add check" do
    end
  end
end
