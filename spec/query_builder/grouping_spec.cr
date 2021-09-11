require "../spec_helper"

describe Jennifer::QueryBuilder::Grouping do
  described_class = Jennifer::QueryBuilder::Grouping
  c1 = Factory.build_criteria
  c2 = Factory.build_criteria == 2

  describe ".new" do
    context "with query" do
      it do
        g = described_class.new(Query["contacts"].where { _id == 2 })
        g.as_sql
          .should eq(%((SELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")} WHERE #{quote_identifier("contacts.id")} = %s )))
      end
    end
  end

  describe "#as_sql" do
    it "wrap SQL with parenthesis" do
      g = described_class.new(c1 & c2)
      g.as_sql.should match(/\(#{reg_quote_identifier("tests.f1")} AND #{reg_quote_identifier("tests.f1")} = %s\)/)
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
