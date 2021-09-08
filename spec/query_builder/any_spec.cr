require "../spec_helper"

describe Jennifer::QueryBuilder::Any do
  query = Contact.all.where { _id == 2 }
  expression = Factory.build_expression

  describe "#as_sql" do
    it "wrap SQL with ANY operator" do
      expression.any(query).as_sql.should match(/ANY \(SELECT .*\)/m)
    end

    it "nested request includes template argument placeholders" do
      expression.any(query).as_sql.should match(/#{reg_quote_identifier("id")} = %s/)
    end
  end

  describe "#sql_args" do
    it "returns arguments from nested query" do
      expression.any(query).sql_args.should eq([2])
    end
  end

  describe "#filterable?" do
    it { expression.any(Query["contacts"].where { _name == "asd" }).filterable?.should be_true }
    it { expression.any(Query["contacts"]).filterable?.should be_false }
  end
end
