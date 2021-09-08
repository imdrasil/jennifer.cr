require "../spec_helper"

describe Jennifer::QueryBuilder::All do
  query = Contact.all.where { _id == 2 }
  expression = Factory.build_expression

  describe "#as_sql" do
    it "wrap SQL with ALL operator" do
      expression.all(query).as_sql.should match(/ALL \(SELECT .*\)/m)
    end

    it "nested request includes template argument placeholders" do
      expression.all(query).as_sql.should match(/#{reg_quote_identifier("id")} = %s/)
    end
  end

  describe "#sql_args" do
    it "returns arguments from nested query" do
      expression.all(query).sql_args.should eq([2])
    end
  end

  describe "#filterable?" do
    it { expression.all(Query["contacts"].where { _name == "asd" }).filterable?.should be_true }
    it { expression.all(Query["contacts"]).filterable?.should be_false }
  end
end
