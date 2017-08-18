require "../spec_helper"

describe ::Jennifer::QueryBuilder::ExpressionBuilder do
  describe "magic methods" do
    context "table and attribute generation" do
      it "accepts only attribute names" do
        eb = Factory.build_expression(table: "table")
        c = eb._some_field
        c.field.should eq("some_field")
        c.table.should eq("table")
      end

      it "accepts first part as table name" do
        eb = Factory.build_expression(table: "table")
        c = eb._some_table__some_field
        c.field.should eq("some_field")
        c.table.should eq("some_table")
      end

      it "accepts model name as first part if such model exists" do
        eb = Factory.build_expression(table: "table")
        c = eb._contact__name
        c.field.should eq("name")
        c.table.should eq(Contact.table_name)
      end
    end

    context "adding relation scope" do
      it "automatically adds relation to nexted criterias" do
        eb = Factory.build_expression(table: "table")
        c = eb.__some_relation { _some_table__field }
        c.field.should eq("field")
        c.table.should eq("some_table")
        c.relation.should eq("some_relation")
      end

      it "sets flag for query to check tables for auto aliasing" do
        q = Contact.all
        eb = q.expression_builder
        eb.__some_relation { _some_table__field }
        q.with_relation?.should be_true
      end
    end
  end

  describe "#c" do
    it "creates criteria with given field name" do
      c = Factory.build_expression.c("some field")
      c.should be_a(Jennifer::QueryBuilder::Criteria)
      c.field.should eq("some field")
    end
  end

  describe "#sql" do
    it "creates raw sql criteria with given sql and parameters" do
      c = Factory.build_expression.sql("contacts.name LIKE ?", ["%jo%"])
      c.should be_a(Jennifer::QueryBuilder::RawSql)
      c.field.should eq("contacts.name LIKE ?")
    end
  end
end
