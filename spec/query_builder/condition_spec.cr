require "../spec_helper"

describe Jennifer::QueryBuilder::Condition do
  describe "#to_sql" do
    {% for op in [:<, :>, :<=, :>=, :!=] %}
        context "{{op.id}} operator" do
          it "retruns string representation" do
            criteria_builder.{{op.id}}("asd").to_sql.should eq("tests.f1 {{op.id}} %s")
          end
        end
      {% end %}

    context "operator ==" do
      it "returns short" do
        (criteria_builder == "asd").to_sql.should eq("tests.f1 = %s")
      end
    end

    context "operator =~" do
      it "returns regexp operator" do
        cond = criteria_builder =~ "asd"
        if Jennifer::Adapter.adapters.keys.last == "postgres"
          cond.to_sql.should match(/~/)
        else
          cond.to_sql.should match(/REGEXP/)
        end
      end
    end

    context "operator LIKE" do
      it "finds correct results" do
        contact_create(name: "Abraham")
        contact_create(name: "Johny")
        Contact.where { _name.like("%oh%") }.count.should eq(1)
      end
    end

    context "operator is bool" do
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
        criteria_builder.in([1, "asd"]).sql_args.should eq(db_array(1, "asd"))
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

  describe "#filter_out" do
    context "is Criteria" do
      it "renders sql of criteria" do
        c1 = criteria_builder.to_condition
        c2 = criteria_builder
        c1.filter_out(c2).should eq(c2.to_sql)
      end
    end

    context "anything else" do
      it "renders question mark" do
        c1 = criteria_builder.to_condition
        c1.filter_out(1).should eq("%s")
        c1.filter_out("s").should eq("%s")
        c1.filter_out(false).should eq("%s")
      end
    end
  end
end
