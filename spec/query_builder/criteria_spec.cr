require "../spec_helper"

describe Jennifer::QueryBuilder::Criteria do
  # all sql checks are in operator_spec.cr
  {% for op in [:==, :<, :>, :<=, :>=, :!=] %}
    describe "#{{{op.stringify}}}" do
      it "retruns condition" do
        c = Factory.build_criteria
        cond = (c {{op.id}} "a")
        cond.should be_a Jennifer::QueryBuilder::Condition
        cond.operator.should eq({{op}})
      end
    end
  {% end %}

  describe "#=~" do
    it "retruns condition" do
      c = Factory.build_criteria
      cond = (c =~ "a")
      cond.should be_a Jennifer::QueryBuilder::Condition
      cond.operator.should eq(:regexp)
    end
  end

  describe "#is_nil" do
    pending "fill it" do
    end

    it "works via == as well" do
      c = Factory.build_criteria(field: "f1") == nil
      c.as_sql.should eq("tests.f1 IS NULL")
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
      c = Factory.build_criteria
      expect_raises(Exception, "IN array can't be empty") do
        c.in([] of DB::Any)
      end
    end

    it "accepts all DB::Any types at the same time" do
      c = Factory.build_criteria.in([1, "asd"])
      c.rhs.should eq(db_array(1, "asd"))
    end

    it "sets operator as :in" do
      c = Factory.build_criteria
      c.in([1]).operator.should eq(:in)
    end
  end

  describe "#&" do
    it "retruns AND operator" do
      (Factory.build_criteria & Factory.build_criteria).should be_a(Jennifer::QueryBuilder::And)
    end
  end

  describe "#|" do
    it "retruns OR operator" do
      (Factory.build_criteria | Factory.build_criteria).should be_a(Jennifer::QueryBuilder::Or)
    end
  end

  describe "#take" do
    it "creates json selector with proper type" do
      c = Factory.build_criteria
      s = c.take(1)
      s.is_a?(Jennifer::QueryBuilder::JSONSelector)
      s.table.should eq(c.table)
      s.field.should eq(c.field)
      s.type.should eq(:take)
      s.path.should eq(1)
    end
  end

  describe "#path" do
    it "creates json selector with proper type" do
      c = Factory.build_criteria
      s = c.path("w")
      s.is_a?(Jennifer::QueryBuilder::JSONSelector)
      s.table.should eq(c.table)
      s.field.should eq(c.field)
      s.type.should eq(:path)
      s.path.should eq("w")
    end
  end

  describe "#to_sql" do
    pending "add" do
    end
  end

  describe "#sql_args" do
    it "returns empty array" do
      Factory.build_criteria.sql_args.empty?.should be_true
    end
  end
end
