require "../spec_helper"

describe Jennifer::QueryBuilder::Join do
  describe "#to_sql" do
    it "includes table name" do
      join_builder.to_sql.should match(/ tests ON /)
    end

    it "calls to_sql on @on" do
      c = criteria_builder
      join_builder(on: c).to_sql.should match(/#{c.to_sql}$/)
    end

    context "left" do
      it "starts with left" do
        join_builder(type: :left).to_sql.should match(/^LEFT JOIN/)
      end
    end

    context "right" do
      it "starts with right" do
        join_builder(type: :right).to_sql.should match(/^RIGHT JOIN/)
      end
    end

    context "inner" do
      it "starts with pure join" do
        join_builder.to_sql.should match(/^JOIN/)
      end
    end
  end

  describe "#sql_args" do
    it "returns sql args of @on" do
      c = criteria_builder(field: "f2")
      join_builder(on: c).sql_args.should eq(c.sql_args)
    end
  end
end
