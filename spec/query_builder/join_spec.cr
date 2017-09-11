require "../spec_helper"

describe Jennifer::QueryBuilder::Join do
  describe "#to_sql" do
    it "includes table name" do
      Factory.build_join.as_sql.should match(/ tests ON /)
    end

    it "calls to_sql on @on" do
      c = Factory.build_criteria
      Factory.build_join(on: c).as_sql.should match(/#{c.as_sql}$/)
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
  end

  describe "#sql_args" do
    it "returns sql args of @on" do
      c = Factory.build_criteria(field: "f2")
      Factory.build_join(on: c).sql_args.should eq(c.sql_args)
    end
  end
end
