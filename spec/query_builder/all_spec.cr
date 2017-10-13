require "../spec_helper"

describe Jennifer::QueryBuilder::All do
  described_class = Jennifer::QueryBuilder::All
  query = Contact.all.where { _id == 2 }

  describe "#as_sql" do
    it "wrap sql with ALL operator" do
      all = Factory.build_expression.all(query)
      all.as_sql.should match(/ALL \(SELECT .*\)/m)
    end

    it "nested request includes template argument placeholders" do
      all = Factory.build_expression.all(query)
      all.as_sql.should match(/id = %s/)
    end
  end

  describe "#sql_args" do
    it "returns arguments from nested query" do
      all = Factory.build_expression.all(query)
      all.sql_args.should eq([2])
    end
  end
end
