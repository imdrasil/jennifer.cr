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
    it "creates raw SQL criteria from given SQL and parameters" do
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

  describe "#and" do
    it "accepts 2 conditions" do
      c1 = Factory.build_criteria
      c2 = Factory.build_criteria
      e = Factory.build_expression
      e.and(c1, c2).as_sql.should eq(e.g(c1 & c2).as_sql)
    end

    it "accepts 3 conditions" do
      c1 = Factory.build_criteria(field: "f1")
      c2 = Factory.build_criteria(field: "f2")
      c3 = Factory.build_criteria(field: "f3")
      e = Factory.build_expression
      e.and(c1, c2, c3).as_sql.should eq(e.g(c1 & c2 & c3).as_sql)
    end

    it "accepts array of 1 condition" do
      c1 = Factory.build_criteria(field: "f1").equal(1)
      e = Factory.build_expression
      e.and([c1]).as_sql.should eq(c1.as_sql)
    end

    it "accepts array of 2 conditions" do
      c1 = Factory.build_criteria(field: "f1").equal(1)
      c2 = Factory.build_criteria(field: "f2").equal(2)
      e = Factory.build_expression
      e.and([c1, c2]).as_sql.should eq(e.g(c1 & c2).as_sql)
    end

    it "accepts array of 3 and more conditions" do
      c1 = Factory.build_criteria(field: "f1").equal(1)
      c2 = Factory.build_criteria(field: "f2").equal(2)
      c3 = Factory.build_criteria(field: "f3").equal(3)
      e = Factory.build_expression
      e.and([c1, c2, c3]).as_sql.should eq(e.g(c1 & c2 & c3).as_sql)
    end

    it "raises and error if an empty array is given" do
      expect_raises(ArgumentError, "#and can't accept 0 conditions") do
        e = Factory.build_expression
        e.and([] of Jennifer::QueryBuilder::Condition).as_sql
      end
    end
  end

  describe "#or" do
    it "accepts 2 conditions" do
      c1 = Factory.build_criteria
      c2 = Factory.build_criteria
      e = Factory.build_expression
      e.or(c1, c2).as_sql.should eq(e.g(c1 | c2).as_sql)
    end

    it "accepts 3 conditions" do
      c1 = Factory.build_criteria(field: "f1")
      c2 = Factory.build_criteria(field: "f2")
      c3 = Factory.build_criteria(field: "f3")
      e = Factory.build_expression
      e.or(c1, c2, c3).as_sql.should eq(e.g(c1 | c2 | c3).as_sql)
    end

    it "accepts array of 1 condition" do
      c1 = Factory.build_criteria(field: "f1").equal(1)
      e = Factory.build_expression
      e.or([c1]).as_sql.should eq(c1.as_sql)
    end

    it "accepts array of 2 conditions" do
      c1 = Factory.build_criteria(field: "f1").equal(1)
      c2 = Factory.build_criteria(field: "f2").equal(2)
      e = Factory.build_expression
      e.or([c1, c2]).as_sql.should eq(e.g(c1 | c2).as_sql)
    end

    it "accepts array of 3 and more conditions" do
      c1 = Factory.build_criteria(field: "f1").equal(1)
      c2 = Factory.build_criteria(field: "f2").equal(2)
      c3 = Factory.build_criteria(field: "f3").equal(3)
      e = Factory.build_expression
      e.or([c1, c2, c3]).as_sql.should eq(e.g(c1 | c2 | c3).as_sql)
    end

    it "raises and error if an empty array is given" do
      expect_raises(ArgumentError, "#or can't accept 0 conditions") do
        e = Factory.build_expression
        e.or([] of Jennifer::QueryBuilder::Condition).as_sql
      end
    end
  end

  describe "#xor" do
    it "accepts 2 conditions" do
      c1 = Factory.build_criteria
      c2 = Factory.build_criteria
      e = Factory.build_expression
      e.xor(c1, c2).as_sql.should eq(e.g(c1.xor(c2)).as_sql)
    end

    it "accepts 3 conditions" do
      c1 = Factory.build_criteria(field: "f1")
      c2 = Factory.build_criteria(field: "f2")
      c3 = Factory.build_criteria(field: "f3")
      e = Factory.build_expression
      e.xor(c1, c2, c3).as_sql.should eq(e.g(c1.xor(c2.xor(c3))).as_sql)
    end

    it "accepts array of 1 condition" do
      c1 = Factory.build_criteria(field: "f1").equal(1)
      e = Factory.build_expression
      e.xor([c1]).as_sql.should eq(c1.as_sql)
    end

    it "accepts array of 2 conditions" do
      c1 = Factory.build_criteria(field: "f1").equal(1)
      c2 = Factory.build_criteria(field: "f2").equal(2)
      e = Factory.build_expression
      e.xor([c1, c2]).as_sql.should eq(e.g(c1.xor(c2)).as_sql)
    end

    it "accepts array of 3 and more conditions" do
      c1 = Factory.build_criteria(field: "f1").equal(1)
      c2 = Factory.build_criteria(field: "f2").equal(2)
      c3 = Factory.build_criteria(field: "f3").equal(3)
      e = Factory.build_expression
      e.xor([c1, c2, c3]).as_sql.should eq(e.g(c1.xor(c2.xor(c3))).as_sql)
    end

    it "raises and error if an empty array is given" do
      expect_raises(ArgumentError, "#xor can't accept 0 conditions") do
        e = Factory.build_expression
        e.xor([] of Jennifer::QueryBuilder::Condition).as_sql
      end
    end
  end
end
