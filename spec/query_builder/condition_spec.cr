require "../spec_helper"

describe Jennifer::QueryBuilder::Condition do
  expression = Factory.build_expression

  describe "#as_sql" do
    {% for op in [:<, :>, :<=, :>=, :!=] %}
      context "{{op.id}} operator" do
        it "returns string presentation" do
          Factory.build_criteria.{{op.id}}("asd").as_sql.should eq(%(#{quote_identifier("tests.f1")} {{op.id}} %s))
        end
      end

      context "with model query" do
        it do
          c = Factory.build_criteria
          query = grouping(Contact.all.where { _age > 12 }.select { [_id] })
          c.{{op.id}}(query).as_sql.should eq(%(#{quote_identifier("tests.f1")} {{op.id}} #{query.as_sql}))
        end
      end

      context "with query" do
        it do
          c = Factory.build_criteria
          query = grouping(Query["contacts"].where { _age > 12 }.select { [_id] })
          c.{{op.id}}(query).as_sql.should eq(%(#{quote_identifier("tests.f1")} {{op.id}} #{query.as_sql}))
        end
      end
    {% end %}

    context "= operator" do
      it { (Factory.build_criteria == "asd").as_sql.should eq(%(#{quote_identifier("tests.f1")} = %s)) }

      context "with model query" do
        it do
          c = Factory.build_criteria
          query = grouping(Contact.all.where { _age > 12 }.select { [_id] })
          c.==(query).as_sql.should eq(%(#{quote_identifier("tests.f1")} = #{query.as_sql}))
        end
      end

      context "with query" do
        it do
          c = Factory.build_criteria
          query = grouping(Query["contacts"].where { _age > 12 }.select { [_id] })
          c.==(query).as_sql.should eq(%(#{quote_identifier("tests.f1")} = #{query.as_sql}))
        end
      end
    end

    postgres_only do
      context "operator overlap" do
        it "accepts plain args" do
          Factory.build_criteria.overlap([1, 2]).as_sql.should eq(%("tests"."f1" && %s))
        end

        it "accepts criteria" do
          Factory.build_criteria.overlap(Factory.build_criteria).as_sql.should eq(%("tests"."f1" && "tests"."f1"))
        end
      end

      context "operator contain" do
        it "accepts plain args" do
          Factory.build_criteria.contain([1, 2]).as_sql.should eq(%("tests"."f1" @> %s))
        end

        it "accepts criteria" do
          Factory.build_criteria.contain(Factory.build_criteria).as_sql.should eq(%("tests"."f1" @> "tests"."f1"))
        end
      end

      context "operator contained" do
        it "accepts plain args" do
          Factory.build_criteria.contained([1, 2]).as_sql.should eq(%("tests"."f1" <@ %s))
        end

        it "accepts criteria" do
          Factory.build_criteria.contained(Factory.build_criteria).as_sql.should eq(%("tests"."f1" <@ "tests"."f1"))
        end
      end
    end

    context "=~ operator" do
      it "returns regexp operator" do
        sql = (Factory.build_criteria =~ "asd").as_sql

        db_specific(
          mysql: ->{ sql.should match(/REGEXP/) },
          postgres: ->{ sql.should match(/~/) }
        )
      end
    end

    context "BETWEEN operator" do
      it "generates proper SQL" do
        expression._age.between(20, 30).as_sql.should match(/#{reg_quote_identifier("age")} BETWEEN %s AND %s/)
      end
    end

    context "LIKE operator" do
      it "finds correct results" do
        Factory.create_contact(name: "Abraham")
        Factory.create_contact(name: "Johny")
        Contact.where { _name.like("%oh%") }.count.should eq(1)
      end
    end

    context "bool" do
      it "renders table name and field name" do
        Factory.build_criteria.to_condition.as_sql.should eq(quote_identifier("tests.f1"))
      end
    end

    context "IN operator" do
      context "with array" do
        it "correctly renders" do
          Factory.build_criteria.in([1, "asd"]).as_sql.should eq(%(#{quote_identifier("tests.f1")} IN(%s, %s)))
        end

        context "with 0 size" do
          it "renders impossible condition" do
            Factory.build_criteria.in(%w()).as_sql.should eq("1 = 0")
          end
        end
      end

      context "with model query" do
        it do
          c = Factory.build_criteria
          query = grouping(Contact.all.where { _age > 12 }.select { [_id] })
          c.in(query).as_sql.should eq(%(#{quote_identifier("tests.f1")} IN(#{query.as_sql})))
        end
      end

      context "with query" do
        it do
          c = Factory.build_criteria
          query = grouping(Query["contacts"].where { _age > 12 }.select { [_id] })
          c.in(query).as_sql.should eq(%(#{quote_identifier("tests.f1")} IN(#{query.as_sql})))
        end
      end
    end

    context "regular operator" do
      it "renders table name, field name and operator" do
        (Factory.build_criteria != 1).as_sql.should match(/^#{reg_quote_identifier("tests.f1")} !=/)
      end

      it "renders escape symbol if rhs is regular argument" do
        (Factory.build_criteria != 1).as_sql.should match(/%s$/)
      end

      it "renders field if rhs is criteria" do
        (Factory.build_criteria != Factory.build_criteria(field: "f2")).as_sql.should match(/#{reg_quote_identifier("tests.f2")}$/)
      end
    end
  end

  describe "#sql_args" do
    context "bool operator" do
      it "returns empty array" do
        Factory.build_criteria.to_condition.sql_args.empty?.should be_true
      end
    end

    context "IN operator" do
      context "with array" do
        it "returns array of IN args" do
          Factory.build_criteria.in([1, "asd"]).sql_args.should eq(db_array(1, "asd"))
        end

        context "with 0 size" do
          it "returns empty array" do
            Factory.build_criteria.in(%w()).sql_args.should be_empty
          end
        end
      end

      context "with model query" do
        it do
          c = Factory.build_criteria
          query = grouping(Contact.all.where { _age > 12 }.select { [_id] })
          c.in(query).sql_args.should eq(db_array(12))
        end
      end

      context "with query" do
        it do
          c = Factory.build_criteria
          query = grouping(Query["contacts"].where { _age > 12 }.select { [_id] })
          c.in(query).sql_args.should eq(db_array(12))
        end
      end
    end

    context "rhs isn't a criteria" do
      it "returns rhs as element of array" do
        (Factory.build_criteria > 1).sql_args.should eq(db_array(1))
      end
    end

    context "rhs is a criteria" do
      it "returns empty array" do
        (Factory.build_criteria > Factory.build_criteria).sql_args.empty?.should be_true
      end

      describe "raw SQL" do
        it do
          (expression._name == expression.sql("lower(%s)", ["A"])).sql_args.should eq(["A"])
        end
      end
    end

    context "when lhs is raw SQL" do
      it do
        expression.sql("lower(%s)", ["A"]).sql_args.should eq(["A"])
      end

      context "when rhs is raw SQL" do
        it do
          (expression.sql("lower(%s)", ["A"]) == expression.sql("lower(%s)", ["Q"])).sql_args.should eq(%w(A Q))
        end
      end
    end
  end

  describe "#filterable?" do
    context "with filterable lhs" do
      it { expression.sql("asd", [1]).to_condition.filterable?.should be_true }
    end

    describe "bool condition" do
      it { expression._id.to_condition.filterable?.should be_false }
    end

    context "with lhs SQL node" do
      it { expression._id.==(expression._age).filterable?.should be_false }
      it { expression._id.==(expression.sql("asd", [1])).filterable?.should be_true }
    end

    context "with IS operator" do
      it { expression._id.is(true).filterable?.should be_false }
    end

    context "with IS NOT operator" do
      it { expression._id.not.filterable?.should be_false }
    end

    context "with array rhs" do
      # it { expression._id.in([expression._id]).filterable?.should be_false }
      # it { expression._id.in([expression.sql("asd", [1])]).filterable?.should be_true }
      it { expression._id.in([1, 2]).filterable?.should be_true }
    end

    context "with common argument" do
      it { expression._id.==(1).filterable?.should be_true }
    end
  end

  describe "#not" do
    pending "add" do
    end
  end

  describe "#set_relation" do
    pending "add" do
    end
  end

  describe "#alias_tables" do
    pending "add" do
    end
  end

  describe "#change_table" do
    pending "add" do
    end
  end
end
