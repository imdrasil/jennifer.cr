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
    context "with field name" do
      it "creates criteria with given field name" do
        c = Factory.build_expression.c("some field")
        c.should be_a(Jennifer::QueryBuilder::Criteria)
        c.field.should eq("some field")
      end

      context "with table name" do
        it "assign given table name" do
          c = Factory.build_expression.c("field", "str_table")
          c.table.should eq("str_table")
        end

        context "with relation" do
          it "assigns both table and relation" do
            c = Factory.build_expression.c("f", "t", "r").not_nil!
            c.table.should eq("t")
            c.relation.should eq("r")
          end
        end
      end

      context "with relation" do
        it "assign only relation" do
          c = Factory.build_expression(table: "some_table").c("f1", relation: "r").not_nil!
          c.relation.should eq("r")
          c.table.should eq("some_table")
        end
      end
    end
  end

  describe "#sql" do
    it "creates raw sql criteria with given sql and parameters" do
      c = Factory.build_expression.sql("contacts.name LIKE ?", ["%jo%"])
      c.should be_a(Jennifer::QueryBuilder::RawSql)
      c.field.should eq("contacts.name LIKE ?")
    end
  end

  describe "#star" do
    it "creates star object with current table name by default" do
      c = Factory.build_expression(table: "asd").star
      c.is_a?(Jennifer::QueryBuilder::Star).should be_true
      c.table.should eq("asd")
    end

    it "creates star object with geven table name" do
      c = Factory.build_expression(table: "asd").star("qwe")
      c.table.should eq("qwe")
    end
  end

  describe "#any" do
    it "creates any object with given query" do
      query = Contact.all.where { _id == 1 }
      any = Factory.build_expression.any(query)
      any.is_a?(Jennifer::QueryBuilder::Any).should be_true
      any.query.should eq(query)
    end
  end

  describe "#all" do
    it "creates all object with given query" do
      query = Contact.all.where { _id == 1 }
      all = Factory.build_expression.all(query)
      all.is_a?(Jennifer::QueryBuilder::All).should be_true
      all.query.should eq(query)
    end
  end

  describe "#g" do
    it "creates grouping with given condition" do
      c1 = Factory.build_criteria
      c2 = Factory.build_criteria
      g = Factory.build_expression.g(c1 & c2)
      g.is_a?(Jennifer::QueryBuilder::Grouping).should be_true
    end
  end
end
