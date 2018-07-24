require "../spec_helper"

describe Jennifer::QueryBuilder::LogicOperator do
  described_class = Jennifer::QueryBuilder::LogicOperator
  expression = Factory.build_expression
  c1 = Factory.build_criteria(field: "f1")
  c2 = Factory.build_criteria(field: "f2")

  describe "complex expression with grouping" do
    it "puts parenthesis around proper elements" do
      c3 = Factory.build_criteria(field: "f3")
      (c1 & expression.g(c2 | c3)).as_sql.should eq("tests.f1 AND (tests.f2 OR tests.f3)")
    end
  end

  describe "#as_sql" do
    it { ((c1 == 2 ) & (c2 == c1)).as_sql.should eq("tests.f1 = %s AND tests.f2 = tests.f1") }
  end

  describe "#sql_args" do
    it { ((c1 == 2 ) & (c2 == c1)).sql_args.should eq([2]) }
  end

  describe "#filterable?" do
    it { ((c1 == 2 ) & (c2 == c1)).filterable?.should be_true }
    it { (c2 == c1).filterable?.should be_false }
  end

  describe "And" do
    describe "#operator" do
      it { Jennifer::QueryBuilder::And.new(Factory.build_criteria.to_condition, Factory.build_criteria.to_condition).operator.should eq("AND") }
    end
  end

  describe "Or" do
    describe "#operator" do
      it { Jennifer::QueryBuilder::Or.new(Factory.build_criteria.to_condition, Factory.build_criteria.to_condition).operator.should eq("OR") }
    end
  end

  describe "Xor" do
    describe "#operator" do
      it { Jennifer::QueryBuilder::Xor.new(Factory.build_criteria.to_condition, Factory.build_criteria.to_condition).operator.should eq("XOR") }
    end
  end
end
