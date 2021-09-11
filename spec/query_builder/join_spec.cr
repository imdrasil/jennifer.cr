require "../spec_helper"

describe Jennifer::QueryBuilder::Join do
  described_class = Jennifer::QueryBuilder::Join
  expression = Factory.build_expression

  describe ".new" do
    context "with Grouping" do
      it do
        q = Jennifer::QueryBuilder::Query["tests"]
        condition = Factory.build_criteria(table: "t1") == 2
        on_condition = Jennifer::QueryBuilder::Grouping.new(condition)
        described_class.new(q, on_condition, :inner).on.should eq(on_condition.to_condition)
      end
    end
  end

  describe "#as_sql" do
    it "includes table name" do
      Factory.build_join.as_sql.should match(/ #{reg_quote_identifier("tests")} ON /)
    end

    it "calls as_sql on @on" do
      c = Factory.build_criteria
      Factory.build_join(on: c).as_sql.should match(/ON #{c.as_sql}$/)
    end

    context "left" do
      it "starts with left" do
        Factory.build_join(type: :left).as_sql.should match(/^LEFT JOIN/)
      end
    end

    context "right" do
      it "starts with right" do
        Factory.build_join(type: :right).as_sql.should match(/^RIGHT JOIN/)
      end
    end

    context "inner" do
      it "starts with pure join" do
        Factory.build_join.as_sql.should match(/^JOIN/)
      end
    end

    context "full" do
      it "starts with full outer join" do
        Factory.build_join(type: :full).as_sql.should match(/^FULL OUTER JOIN/)
      end
    end

    context "invalid join type" do
      it "raises argument error" do
        expect_raises(ArgumentError, "Bad join type: unknown") do
          Factory.build_join(type: :unknown).as_sql
        end
      end
    end
  end

  describe "#sql_args" do
    it "returns SQL args of @on" do
      c = Factory.build_criteria(field: "f2")
      Factory.build_join(on: c).sql_args.should eq(c.sql_args)
    end

    context "source is a query" do
      it "includes source query SQL arguments" do
        args = Factory.build_join(table: Query["tests2"].where { _id == "asd" }).sql_args
        args.size.should eq(2)
        args[0].should eq("asd")
      end
    end
  end

  describe "#filterable?" do
    context "with filterable condition" do
      it { Factory.build_join(on: expression._id > 1).filterable?.should be_true }
    end

    context "with query as a source" do
      it { Factory.build_join(table: Query["tests2"].where { _id == "asd" }).filterable?.should be_true }

      it do
        condition = expression._id == expression._id
        table = Query["tests2"].where { _id == _age }
        Factory.build_join(on: condition, table: table).filterable?.should be_false
      end
    end

    it { Factory.build_join(on: expression._id == expression._id).filterable?.should be_false }
  end
end

describe Jennifer::QueryBuilder::LateralJoin do
  describe "#as_sql" do
    it "includes source request definition" do
      lateral_join.as_sql
        .should match(/ \(SELECT #{reg_quote_identifier("tests")}\.\* FROM #{reg_quote_identifier("tests")} WHERE #{reg_quote_identifier("tests.id")} = %s \) ON /m)
    end

    it "calls as_sql on @on" do
      c = Factory.build_criteria
      lateral_join(on: c).as_sql.should match(/ON #{c.as_sql}$/)
    end

    context "left" do
      it "starts with left" do
        lateral_join(type: :left).as_sql.should match(/^LEFT JOIN LATERAL/)
      end
    end

    context "right" do
      it "starts with right" do
        lateral_join(type: :right).as_sql.should match(/^RIGHT JOIN LATERAL/)
      end
    end

    context "inner" do
      it "starts with pure join" do
        lateral_join.as_sql.should match(/^JOIN LATERAL/)
      end
    end

    context "full" do
      it "starts with full outer join" do
        lateral_join(type: :full).as_sql.should match(/^FULL OUTER JOIN LATERAL/)
      end
    end

    context "invalid join type" do
      it "raises argument error" do
        expect_raises(ArgumentError, "Bad join type: unknown") do
          lateral_join(type: :unknown).as_sql
        end
      end
    end
  end
end

def lateral_join(type = :inner, on = Factory.build_criteria(table: "t1") == 2)
  q = Jennifer::QueryBuilder::Query["tests"]
  Jennifer::QueryBuilder::LateralJoin.new(q.where { _id == 2 }, on, type)
end
