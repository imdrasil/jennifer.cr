require "../spec_helper"

describe Jennifer::QueryBuilder::Criteria do
  # all sql checks are in operator_spec.cr
  {% for op in [:==, :<, :>, :<=, :>=, :!=, :=~] %}
  	describe "#{{{op.stringify}}}" do
  		it "retruns self" do
  			c = criteria_builder
  			(c {{op.id}} "a").should eq(c)
  		end
  	end
  {% end %}

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
      c = criteria_builder
      c.in([1, "asd"])
      c.rhs.should eq(db_array(1, "asd"))
    end

    it "sets operator as :in" do
      c = criteria_builder
      c.in([1])
      c.operator.should eq(:in)
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

  describe "#filter_out" do
    context "is Criteria" do
      it "renders sql of criteria" do
        c1 = criteria_builder
        c2 = criteria_builder
        c1.filter_out(c2).should eq(c2.to_sql)
      end
    end

    context "anything else" do
      it "renders question mark" do
        c1 = criteria_builder
        c1.filter_out(1).should eq("%s")
        c1.filter_out("s").should eq("%s")
        c1.filter_out(false).should eq("%s")
      end
    end
  end

  describe "#to_sql" do
    context "operator is boo" do
      it "renders table name and field name" do
        criteria_builder.to_sql.should eq("tests.f1")
      end
    end

    context "IN operator" do
      it "renders table name and field name" do
        criteria_builder.in([1, "asd"]).to_sql.should match(/tests\.f1/)
      end

      it "correctly renders IN part (mysql)" do
        criteria_builder.in([1, "asd"]).to_sql.should match(/IN\(%s\, %s\)/)
      end
    end

    context "regular operator" do
      it "renders table name, field name and operator" do
        (criteria_builder != 1).to_sql.should match(/^tests\.f1 !=/)
      end

      it "renders escape symbol if rhs is regular argument" do
        (criteria_builder != 1).to_sql.should match(/%s$/)
      end

      it "renders field if rhs is criteria" do
        (criteria_builder != criteria_builder(field: "f2")).to_sql.should match(/tests\.f2$/)
      end
    end
  end

  describe "#sql_args" do
    context "bool operator" do
      it "returns empty array" do
        criteria_builder.sql_args.empty?.should be_true
      end
    end

    context "IN operator" do
      it "returns array of IN args" do
        criteria_builder.in([1, "asd"]).should eq(db_array(1, "asd"))
      end
    end

    context "rhs is not criteria" do
      it "returns rhs as element of array" do
        (criteria_builder > 1).sql_args.should eq(db_array(1))
      end
    end

    context "rhs is criteria" do
      it "returns empty array" do
        (criteria_builder > criteria_builder).sql_args.empty?.should be_true
      end
    end
  end
end
