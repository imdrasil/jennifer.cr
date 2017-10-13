require "../spec_helper"

describe Jennifer::QueryBuilder::Any do
  described_class = Jennifer::QueryBuilder::Any
  query = Contact.all.where { _id == 2 }

  describe "#as_sql" do
    it "wrap sql with ANY operator" do
      any = Factory.build_expression.any(query)
      any.as_sql.should match(/ANY \(SELECT .*\)/m)
    end

    it "nested request includes template argument placeholders" do
      any = Factory.build_expression.any(query)
      any.as_sql.should match(/id = %s/)
    end
  end

  describe "#sql_args" do
    it "returns arguments from nested query" do
      any = Factory.build_expression.any(query)
      any.sql_args.should eq([2])
    end
  end
end
