require "../spec_helper"

describe Jennifer::QueryBuilder::LogicOperator do
  described_class = Jennifer::QueryBuilder::LogicOperator
  expression = Factory.build_expression

  context "complex expression with grouping" do
    it "puts paranthesis around proper elemets" do
      c1 = Factory.build_criteria(field: "f1")
      c2 = Factory.build_criteria(field: "f2")
      c3 = Factory.build_criteria(field: "f3")
      (c1 & expression.g(c2 | c3)).as_sql.should eq("tests.f1 AND (tests.f2 OR tests.f3)")
    end
  end
end
