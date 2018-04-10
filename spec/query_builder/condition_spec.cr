require "../spec_helper"

describe Jennifer::QueryBuilder::Condition do
  describe "#as_sql" do
    {% for op in [:<, :>, :<=, :>=, :!=] %}
      context "{{op.id}} operator" do
        it "retruns string representation" do
          Factory.build_criteria.{{op.id}}("asd").as_sql.should eq("tests.f1 {{op.id}} %s")
        end
      end
    {% end %}

    context "operator ==" do
      it "returns short" do
        (Factory.build_criteria == "asd").as_sql.should eq("tests.f1 = %s")
      end
    end

    postgres_only do
      context "operator overlap" do
        it "accepts plain args" do
          Factory.build_criteria.overlap([1, 2]).as_sql.should eq("tests.f1 && %s")
        end

        it "accepts criteria" do
          Factory.build_criteria.overlap(Factory.build_criteria).as_sql.should eq("tests.f1 && tests.f1")
        end
      end

      context "operator contain" do
        it "accepts plain args" do
          Factory.build_criteria.contain([1, 2]).as_sql.should eq("tests.f1 @> %s")
        end

        it "accepts criteria" do
          Factory.build_criteria.contain(Factory.build_criteria).as_sql.should eq("tests.f1 @> tests.f1")
        end
      end

      context "operator contained" do
        it "accepts plain args" do
          Factory.build_criteria.contained([1, 2]).as_sql.should eq("tests.f1 <@ %s")
        end

        it "accepts criteria" do
          Factory.build_criteria.contained(Factory.build_criteria).as_sql.should eq("tests.f1 <@ tests.f1")
        end
      end
    end

    context "operator =~" do
      it "returns regexp operator" do
        cond = Factory.build_criteria =~ "asd"

        postgres_only do
          cond.as_sql.should match(/~/)
        end

        mysql_only do
          cond.as_sql.should match(/REGEXP/)
        end
      end
    end

    context "operator between" do
      it "generates proper sql" do
        Jennifer::Query["contacts"].where { _age.between(20, 30) }.to_sql.should match(/age BETWEEN %s AND %s/)
      end
    end

    context "operator LIKE" do
      it "finds correct results" do
        Factory.create_contact(name: "Abraham")
        Factory.create_contact(name: "Johny")
        Contact.where { _name.like("%oh%") }.count.should eq(1)
      end
    end

    context "operator is bool" do
      it "renders table name and field name" do
        Factory.build_criteria.as_sql.should eq("tests.f1")
      end
    end

    context "IN operator" do
      it "renders table name and field name" do
        Factory.build_criteria.in([1, "asd"]).as_sql.should match(/tests\.f1/)
      end

      it "correctly renders IN part (mysql)" do
        Factory.build_criteria.in([1, "asd"]).as_sql.should match(/IN\(%s\, %s\)/)
      end
    end

    context "regular operator" do
      it "renders table name, field name and operator" do
        (Factory.build_criteria != 1).as_sql.should match(/^tests\.f1 !=/)
      end

      it "renders escape symbol if rhs is regular argument" do
        (Factory.build_criteria != 1).as_sql.should match(/%s$/)
      end

      it "renders field if rhs is criteria" do
        (Factory.build_criteria != Factory.build_criteria(field: "f2")).as_sql.should match(/tests\.f2$/)
      end
    end
  end

  describe "#sql_args" do
    context "bool operator" do
      it "returns empty array" do
        Factory.build_criteria.sql_args.empty?.should be_true
      end
    end

    context "IN operator" do
      it "returns array of IN args" do
        Factory.build_criteria.in([1, "asd"]).sql_args.should eq(db_array(1, "asd"))
      end
    end

    context "rhs is not criteria" do
      it "returns rhs as element of array" do
        (Factory.build_criteria > 1).sql_args.should eq(db_array(1))
      end
    end

    context "rhs is criteria" do
      it "returns empty array" do
        (Factory.build_criteria > Factory.build_criteria).sql_args.empty?.should be_true
      end

      describe "raw sql" do
        it do
          Contact.all.where { _name == sql("lower(%s)", ["A"]) }.tree.not_nil!.sql_args.should eq(["A"])
        end
      end
    end

    context "when lhs is raw sql" do
      it do
        Contact.all.where { sql("lower(%s)", ["A"]) }.tree.not_nil!.sql_args.should eq(["A"])
      end

      context "when rhs is raw sql" do
        it do
          Contact.all.where { sql("lower(%s)", ["A"]) == sql("lower(%s)", ["Q"]) }.tree.not_nil!.sql_args.should eq(%w(A Q))
        end
      end
    end
  end

  describe "#sql_args_count" do
    context "bool operator" do
      it "returns empty array" do
        Factory.build_criteria.sql_args_count.should eq(0)
      end
    end

    context "IN operator" do
      it "returns array of IN args" do
        Factory.build_criteria.in([1, "asd"]).sql_args_count.should eq(2)
      end
    end

    context "rhs is not criteria" do
      it "returns rhs as element of array" do
        (Factory.build_criteria > 1).sql_args_count.should eq(1)
      end
    end

    context "rhs is criteria" do
      it "returns empty array" do
        (Factory.build_criteria > Factory.build_criteria).sql_args_count.should eq(0)
      end

      describe "raw sql" do
        it do
          Contact.all.where { _name == sql("lower(%s)", ["A"]) }.tree.not_nil!.sql_args_count.should eq(1)
        end
      end
    end

    context "when lhs is raw sql" do
      it do
        Contact.all.where { sql("lower(%s)", ["A"]) }.tree.not_nil!.sql_args_count.should eq(1)
      end

      context "when rhs is raw sql" do
        it do
          Contact.all.where { sql("lower(%s)", ["A"]) == sql("lower(%s)", ["Q"]) }.tree.not_nil!.sql_args_count.should eq(2)
        end
      end
    end
  end
end
