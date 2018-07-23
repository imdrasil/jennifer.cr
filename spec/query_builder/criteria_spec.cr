require "../spec_helper"

describe Jennifer::QueryBuilder::Criteria do
  described_class = Jennifer::QueryBuilder::Criteria
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

  describe "#is" do
    it "creates is condition" do
      cond = Factory.build_criteria.is(nil)
      cond.operator.should eq(:is)
    end

    context "value is nil" do
      it "creates is condition" do
        c = Factory.build_criteria
        cond = c.is(nil)
        cond.as_sql.should eq("tests.f1 IS NULL")
        cond.sql_args.empty?.should be_true
      end
    end

    context "value is true" do
      it "creates is condition" do
        cond = Factory.build_criteria.is(true)
        cond.as_sql.should eq("tests.f1 IS TRUE")
        cond.sql_args.empty?.should be_true
      end
    end

    context "value is false" do
      it "creates is condition" do
        c = Factory.build_criteria
        cond = c.is(false)
        cond.as_sql.should eq("tests.f1 IS FALSE")
        cond.sql_args.empty?.should be_true
      end
    end

    it "works via == and nil as well" do
      c = Factory.build_criteria(field: "f1") == nil
      c.as_sql.should eq("tests.f1 IS NULL")
      c.sql_args.empty?.should be_true
    end
  end

  describe "#not" do
    it "creates not condition" do
      cond = Factory.build_criteria.not(nil)
      cond.operator.should eq(:is_not)
    end

    context "value is nil" do
      it "creates is condition" do
        cond = Factory.build_criteria.not(nil)
        cond.as_sql.should eq("tests.f1 IS NOT NULL")
        cond.sql_args.empty?.should be_true
      end
    end

    context "value is true" do
      it "creates is condition" do
        cond = Factory.build_criteria.not(true)
        cond.as_sql.should eq("tests.f1 IS NOT TRUE")
        cond.sql_args.empty?.should be_true
      end
    end

    context "value is false" do
      it "creates is condition" do
        cond = Factory.build_criteria.not(false)
        cond.as_sql.should eq("tests.f1 IS NOT FALSE")
        cond.sql_args.empty?.should be_true
      end
    end

    context "without arguments" do
      it "creates inversed condition" do
        cond = Factory.build_criteria.not
        cond.as_sql.should eq("NOT (tests.f1)")
      end
    end

    it "works via != and nil as well" do
      c = Factory.build_criteria(field: "f1") != nil
      c.as_sql.should eq("tests.f1 IS NOT NULL")
      c.sql_args.empty?.should be_true
    end
  end

  describe "#in" do
    it "raises error if giben array is empty" do
      c = Factory.build_criteria
      expect_raises(Exception, "IN array can't be empty") do
        c.in([] of Jennifer::DBAny)
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
    it "returns AND operator" do
      (Factory.build_criteria & Factory.build_criteria).should be_a(Jennifer::QueryBuilder::And)
    end
  end

  describe "#|" do
    it "returns OR operator" do
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

  describe "#as_sql" do
    it "returns identifier" do
      c = Factory.build_criteria
      c.as_sql.should eq(c.identifier)
    end
  end

  describe "#sql_args" do
    it "returns empty array" do
      Factory.build_criteria.sql_args.empty?.should be_true
    end
  end

  describe "#filterable?" do
    it { Factory.build_criteria.filterable?.should be_false }
  end

  describe "#alias" do
    it "sets alias" do
      Factory.build_criteria.alias("sdf").alias.should eq("sdf")
    end
  end

  describe "#identifier" do
    it "returns table name and field separated by dot" do
      Factory.build_criteria(table: "tab", field: "field").identifier.should eq("tab.field")
    end
  end

  describe "#definition" do
    context "with alias" do
      it "add alias name at the end" do
        Factory.build_criteria.alias("asd").definition.ends_with?("AS asd").should be_true
      end
    end

    it "renders identifier" do
      c = Factory.build_criteria
      c.definition.should eq(c.identifier)
    end
  end
end
