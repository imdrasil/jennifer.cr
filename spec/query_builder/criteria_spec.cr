require "../spec_helper"

describe Jennifer::QueryBuilder::Criteria do
  # all sql checks are in operator_spec.cr
  {% for op in [:==, :<, :>, :<=, :>=, :!=] %}
    describe "#{{{op.stringify}}}" do
      it "retruns condition" do
        c = criteria_builder
        cond = (c {{op.id}} "a")
        cond.should be_a Jennifer::QueryBuilder::Condition
        cond.operator.should eq({{op}})
      end
    end
  {% end %}

  describe "#=~" do
    it "retruns condition" do
      c = criteria_builder
      cond = (c =~ "a")
      cond.should be_a Jennifer::QueryBuilder::Condition
      cond.operator.should eq(:regexp)
    end
  end

  describe "#is_nil" do
    pending "fill it" do
    end

    it "works via == as well" do
      c = criteria_builder(field: "f1") == nil
      c.to_sql.should eq("tests.f1 IS NULL")
      c.sql_args.empty?.should be_true
    end
  end

  describe "#not_nil" do
    pending "fill it" do
    end

    pending "via != as well" do
    end
  end

  describe "#in" do
    it "raises error if giben array is empty" do
      c = criteria_builder
      expect_raises(Exception, "IN array can't be empty") do
        c.in([] of DB::Any)
      end
    end

    it "accepts all DB::Any types at the same time" do
      c = criteria_builder.in([1, "asd"])
      c.rhs.should eq(db_array(1, "asd"))
    end

    it "sets operator as :in" do
      c = criteria_builder
      c.in([1]).operator.should eq(:in)
    end
  end

  describe "#&" do
    it "retruns AND operator" do
      (criteria_builder & criteria_builder).should be_a(Jennifer::QueryBuilder::And)
    end
  end

  describe "#|" do
    it "retruns OR operator" do
      (criteria_builder | criteria_builder).should be_a(Jennifer::QueryBuilder::Or)
    end
  end

  describe "#to_sql" do
    pending "add" do
    end
  end

  describe "#sql_args" do
    it "returns empty array" do
      criteria_builder.sql_args.empty?.should be_true
    end
  end
end
