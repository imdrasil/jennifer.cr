require "../spec_helper"

describe Jennifer::QueryBuilder::Join do
  describe "#as_sql" do
    it "includes table name" do
      Factory.build_join.as_sql.should match(/ tests ON /)
    end

    it "calls to_sql on @on" do
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
    it "returns sql args of @on" do
      c = Factory.build_criteria(field: "f2")
      Factory.build_join(on: c).sql_args.should eq(c.sql_args)
    end

    context "source is a query" do
      it "includes source query sql arguments" do
        args = Factory.build_join(table: Query["tests2"].where { _id == "asd" }).sql_args
        args.size.should eq(2)
        args[0].should eq("asd")
      end
    end
  end
end

describe Jennifer::QueryBuilder::LateralJoin do
  described_class = Jennifer::QueryBuilder::LateralJoin

  describe "#as_sql" do
    it "includes source request definition" do
      lateral_join.as_sql.should match(/ \(SELECT tests\.\*\nFROM tests\nWHERE tests\.id = %s\n\) ON /m)
    end

    it "calls to_sql on @on" do
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
