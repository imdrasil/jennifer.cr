require "../spec_helper"

describe Jennifer::QueryBuilder::Query do
  described_class = Jennifer::QueryBuilder::Query

  describe "#to_sql" do
    context "if query tree is not epty" do
      it "retruns sql representation of condition" do
        q = Factory.build_query
        c = Factory.build_criteria
        q.set_tree(c).as_sql.should eq(c.as_sql)
      end
    end

    context "if query tree is empty" do
      it "returns empty string" do
        Factory.build_query.as_sql.should eq("")
      end
    end
  end

  describe "#sql_args" do
    context "if query tree is not epty" do
      it "retruns sql args of condition" do
        q = Factory.build_query
        c = Factory.build_criteria
        q.set_tree(c).sql_args.should eq(c.sql_args)
      end
    end

    context "if query tree is empty" do
      it "returns empty array" do
        Factory.build_query.sql_args.should eq([] of DB::Any)
      end
    end
  end

  describe "#set_tree" do
    context "argument is another query" do
      it "gets it's tree" do
        q1 = Factory.build_query
        q2 = Factory.build_query
        q1.set_tree(Factory.build_expression.c("f1"))
        q2.set_tree(q1)
        q1.tree.should be(q2.tree)
      end
    end

    context "has own tree" do
      it "makes AND with new criteria" do
        q1 = Factory.build_query
        c1 = Factory.build_criteria
        c2 = Factory.build_criteria(field: "f2")

        q1.set_tree(c1)
        q1.set_tree(c2)
        q1.tree.should be_a Jennifer::QueryBuilder::And
      end
    end

    context "is empty" do
      it "makes given criteria as own" do
        q1 = Factory.build_query
        c1 = Factory.build_criteria

        q1.set_tree(c1)
        q1.tree.as(Jennifer::QueryBuilder::Condition).lhs.should eq(c1)
      end
    end
  end

  describe "#select" do
    context "with string argument" do
      it "uses argument as raw sql" do
        described_class["table"].select("raw sql")._raw_select.should eq("raw sql")
      end
    end

    context "with symbol" do
      it "creates criteria for given fields and current table" do
        fields = described_class["table"].select(:f1)._select_fields
        fields.size.should eq(1)
        fields[0].field.should eq("f1")
        fields[0].table.should eq("table")
      end
    end

    context "with symbol tuple" do
      it "adds all as criteria" do
        fields = described_class["table"].select(:f1, :f2)._select_fields
        fields.size.should eq(2)
        fields[0].field.should eq("f1")
        fields[1].field.should eq("f2")
      end
    end

    context "with criteria" do
      it "adds it to select fields" do
        fields = described_class["table"].select(Contact._id)._select_fields
        fields.size.should eq(1)
        fields[0].field.should eq("id")
        fields[0].table.should eq("contacts")
      end

      context "as raw sql" do
        it "removes brackets" do
          field = described_class["table"].select(Contact.context.sql("some sql"))._select_fields[0]
          field.identifier.should eq("some sql")
        end
      end
    end

    context "with array of criterias" do
      it "removes brackets for all raw sql" do
        fields = described_class["table"].select([Contact._id, Contact.context.sql("some sql")])._select_fields
        fields.size.should eq(2)
        fields[1].identifier.should eq("some sql")
      end
    end

    context "with block" do
      it "yield expression builder as current context and accepts array" do
        fields = described_class["table"].select { [_f1, Contact._id] }._select_fields
        fields.size.should eq(2)
        fields[0].field.should eq("f1")
        fields[0].table.should eq("table")
      end

      it "removes brackets from raw sql" do
        field = described_class["table"].select { [sql("f1")] }._select_fields[0]
        field.identifier.should eq("f1")
      end
    end
  end

  describe "#where" do
    it "allows to pass criteria and sets it via AND" do
      q1 = Factory.build_query
      c = Factory.build_criteria(field: "f1") & Factory.build_criteria(field: "f2")
      q1.where { c("f1") & c("f2") }
      q1.tree.to_s.should match(/tests\.f1 AND tests\.f2/)
    end
  end

  describe "#having" do
    it "returns correct entities" do
      Factory.create_contact(name: "Ivan", age: 15)
      Factory.create_contact(name: "Max", age: 19)
      Factory.create_contact(name: "Ivan", age: 50)

      res = Contact.all.select("COUNT(id) as count, contacts.name").group("name").having { sql("COUNT(id)") > 1 }.pluck(:name)
      res.size.should eq(1)
      res[0].should eq("Ivan")
    end

    it "joins several having invocation with AND" do
      Contact.all.having { _id > 1 }.having { _id < 2 }._having!.as_sql.should eq("contacts.id > %s AND contacts.id < %s")
    end
  end

  describe "#group" do
    context "with symbol" do
      it "creates criteria for given fields and current table" do
        fields = described_class["table"].group(:f1)._groups
        fields.size.should eq(1)
        fields[0].field.should eq("f1")
        fields[0].table.should eq("table")
      end
    end

    context "with symbol tuple" do
      it "adds all as criteria" do
        fields = described_class["table"].group(:f1, :f2)._groups
        fields.size.should eq(2)
        fields[0].field.should eq("f1")
        fields[1].field.should eq("f2")
      end
    end

    context "with criteria" do
      it "adds it to select fields" do
        fields = described_class["table"].group(Contact._id)._groups
        fields.size.should eq(1)
        fields[0].field.should eq("id")
        fields[0].table.should eq("contacts")
      end

      context "as raw sql" do
        it "removes brackets" do
          field = described_class["table"].group(Contact.context.sql("some sql"))._groups[0]
          field.identifier.should eq("some sql")
        end
      end
    end

    context "with block" do
      it "yield expression builder as current context and accepts array" do
        fields = described_class["table"].group { [_f1, Contact._id] }._groups
        fields.size.should eq(2)
        fields[0].field.should eq("f1")
        fields[0].table.should eq("table")
      end

      it "removes brackets from raw sql" do
        field = described_class["table"].group { [sql("f1")] }._groups[0]
        field.identifier.should eq("f1")
      end
    end
  end

  describe "#limit" do
    it "sets limit" do
      Contact.all.limit(2).to_sql.should match(/LIMIT 2/m)
    end
  end

  describe "#offset" do
    it "sets offset" do
      Contact.all.offset(2).to_sql.should match(/OFFSET 2/m)
    end
  end

  describe "#from" do
    it "accepts plain query" do
      select_clause(Factory.build_query(table: "contacts").from("select * from contacts where id > 2"))
        .should eq("SELECT contacts.*\nFROM ( select * from contacts where id > 2 ) ")
    end

    it "accepts query object" do
      select_clause(Factory.build_query(table: "contacts").from(Contact.where { _id > 2 }))
        .should eq("SELECT contacts.*\nFROM ( SELECT contacts.*\nFROM contacts\nWHERE contacts.id > %s\n ) ")
    end
  end

  describe "#union" do
    it "adds query to own array of unions" do
      q = Jennifer::Query["table"]
      q.union(Jennifer::Query["table2"]).should eq(q)
      q._unions!.empty?.should be_false
    end
  end

  describe "#_select_fields" do
    context "query has no specified select fields" do
      it "returns array with only star" do
        fields = Contact.all._select_fields
        fields.size.should eq(1)

        fields[0].is_a?(Jennifer::QueryBuilder::Star).should be_true
      end
    end

    context "query has specified fields" do
      it "returns specified fields" do
        fields = Contact.all.select { [_id, _age] }._select_fields
        fields.size.should eq(2)
        fields[0].field.should eq("id")
        fields[1].field.should eq("age")
      end
    end
  end

  describe "#distinct" do
    it "adds DISTINC to SELECT clause" do
      Query["contacts"].select(:age).distinct.to_sql.should match(/SELECT DISTINCT contacts\.age/)
    end

    it "returns uniq rows" do
      Factory.create_contact(name: "a1")
      Factory.create_contact(name: "a2")
      Factory.create_contact(name: "a1")
      r = Contact.all.order(name: :asc).select(:name).distinct.results
      r.size.should eq(2)
      r.map(&.name).should eq(["a1", "a2"])
    end
  end

  describe "#except" do
    it "creates new instance" do
      q = Query["contacts"].where { _id > 2 }
      q.except([""]).should_not eq(q)
    end

    it "creates equal object if nothing to exclude was given" do
      q = Query["contacts"].where { _id > 2 }
      clone = q.except([""])
      clone.eql?(q).should be_true
    end

    it "excludes having if given" do
      q = Query["contacts"].group(:age).having { _age > 20 }
      clone = q.except(["having"])
      clone._having.nil?.should be_true
    end

    it "excludes order if given" do
      q = Query["contacts"].order(age: "asc")
      clone = q.except(["order"])
      clone._order.empty?.should be_true
    end

    it "excludes join if given" do
      q = Query["contacts"].join("passports") { _contact_id == _contacts__id }
      clone = q.except(["join"])
      clone._joins.nil?.should be_true
    end

    it "excludes join if given" do
      q = Query["contacts"].union(Query["contacts"])
      clone = q.except(["union"])
      clone._unions.nil?.should be_true
    end

    it "excludes group if given" do
      q = Query["contacts"].group(:age)
      clone = q.except(["group"])
      clone._groups.empty?.should be_true
    end

    it "excludes muting if given" do
      q = Query["contacts"].join("passports") { _contact_id == _contacts__id }
      clone = q.except(["none"])
      clone.eql?(q).should be_true
    end

    it "excludes select if given" do
      q = Query["contacts"].select { [_id] }
      clone = q.except(["select"])
      clone._select_fields.size.should eq(1)
      clone._select_fields[0].should be_a(Jennifer::QueryBuilder::Star)
    end

    it "excludes where if given" do
      q = Query["contacts"].where { _age < 99 }
      clone = q.except(["where"])
      clone.to_sql.should_not match(/WHERE/)
    end

    it "expression builder follow newly created object" do
      q = Query["contacts"]
      clone = q.except([""])
      clone.expression_builder.query.should eq(clone)
    end

    it "automatially ignores any relation usage" do
      q = Contact.all.eager_load(:addresses)
      clone = q.except([""])
      clone.with_relation?.should be_false
      clone._joins!.empty?.should be_false
    end
  end
end
