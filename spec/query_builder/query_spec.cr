require "../spec_helper"

describe Jennifer::QueryBuilder::Query do
  described_class = Jennifer::QueryBuilder::Query

  describe "#as_sql" do
    it "returns SQL presentation of condition" do
      q = Factory.build_query
      c = Factory.build_criteria
      q.where { c }.as_sql
        .should eq(%(SELECT #{quote_identifier("tests")}.* FROM #{quote_identifier("tests")} WHERE #{quote_identifier("tests.f1")} ))
    end
  end

  describe "#sql_args" do
    query = Query["contacts"]
      .select { [abs(1)] }
      .from(Query["contacts"].where { _id > 2 })
      .join("profiles") { _contact_id == 3 }
      .where { _id > 4 }
      .group(:age)
      .having { _age > 5 }

    it { query.sql_args.should eq([1, 2, 3, 4, 5]) }

    pending "add tests for all cases" do
    end
  end

  describe "#filterable?" do
    context "with arguments in SELECT clause" do
      it { Query["contacts"].select { [abs(1)] }.filterable?.should be_true }
    end

    context "with arguments in FROM clause" do
      it { Query["contacts"].from(Query["contacts"].where { _id > 1 }).filterable?.should be_true }
    end

    context "with arguments in JOIN clause" do
      it { Query["contacts"].join("profiles") { _id > 1 }.filterable?.should be_true }
    end

    context "with arguments in WHERE clause" do
      it { Query["contacts"].where { _id > 1 }.filterable?.should be_true }
    end

    context "with arguments in select clause" do
      it { Query["contacts"].group(:age).having { _age > 10 }.filterable?.should be_true }
    end

    context "with query argument with arguments" do
      it { Query["contacts"].where { _id == g(Query["users"].where { _id > 2 }.limit(1)) }.filterable?.should be_true }
    end

    context "without arguments" do
      it do
        Query["contacts"]
          .select { [abs(_id)] }
          .from(Query["contacts"].where { _id > _age })
          .join("profiles") { _contact_id == _contacts__id }
          .where { _id > _age }
          .group(:age).having { _age == _age }
          .filterable?.should be_false
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

    context "with nil" do
      it { expect_raises(ArgumentError) { Factory.build_query.set_tree(nil) } }
    end
  end

  describe "#select" do
    context "with string argument" do
      it "uses argument as raw SQL" do
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

      context "as raw SQL" do
        it "removes brackets" do
          field = described_class["table"].select(Contact.context.sql("some sql"))._select_fields[0]
          field.identifier.should eq("some sql")
        end
      end
    end

    context "with array of criterion" do
      it "removes brackets for all raw SQL" do
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

      it "removes brackets from raw SQL" do
        field = described_class["table"].select { [sql("f1")] }._select_fields[0]
        field.identifier.should eq("f1")
      end
    end
  end

  describe "#where" do
    it "allows to pass criteria and sets it via AND" do
      q1 = Factory.build_query.where { c("f1") & c("f2") }
      q1.tree.to_s.should match(/#{reg_quote_identifier("tests.f1")} AND #{reg_quote_identifier("tests.f2")}/)
    end

    it "generates proper request for given raw SQL as condition part with arguments" do
      q1 = Query["contacts"].where { (_name == "John") & sql("age > %s", [12]) }
      q1.tree.to_s.should eq(%(#{quote_identifier("contacts.name")} = %s AND (age > %s)))
    end

    it "generates correct request for given symbol-key hash" do
      q1 = Query["contacts"].where({:name => "John", :age => 12})
      q1.tree.to_s
        .should eq(%((#{quote_identifier("contacts.name")} = %s AND #{quote_identifier("contacts.age")} = %s)))
      q1.tree.not_nil!.sql_args.should eq(db_array("John", 12))
    end

    it "generates correct request for given string-key hash" do
      q1 = Query["contacts"].where({"name" => "John", "age" => 12})
      q1.tree.to_s
        .should eq(%((#{quote_identifier("contacts.name")} = %s AND #{quote_identifier("contacts.age")} = %s)))
      q1.tree.not_nil!.sql_args.should eq(db_array("John", 12))
    end

    postgres_only do
      it "gracefully handle argument type mismatch" do
        void_transaction do
          expect_raises(Jennifer::BadQuery) do
            Query["contacts"].where { _id == 1.0 }.to_a
          end
          # Next request should be executed without any error
          Query["contacts"].where { _id == 1 }.to_a
        end
      end
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
      Contact.all
        .having { _id > 1 }
        .having { _id < 2 }
        ._having!
        .as_sql
        .should eq(%(#{quote_identifier("contacts.id")} > %s AND #{quote_identifier("contacts.id")} < %s))
    end
  end

  describe "#group" do
    context "with symbol" do
      it "creates criteria for given fields and current table" do
        fields = described_class["table"].group(:f1)._groups!
        fields.size.should eq(1)
        fields[0].field.should eq("f1")
        fields[0].table.should eq("table")
      end
    end

    context "with symbol tuple" do
      it "adds all as criteria" do
        fields = described_class["table"].group(:f1, :f2)._groups!
        fields.size.should eq(2)
        fields[0].field.should eq("f1")
        fields[1].field.should eq("f2")
      end
    end

    context "with criteria" do
      it "adds it to select fields" do
        fields = described_class["table"].group(Contact._id)._groups!
        fields.size.should eq(1)
        fields[0].field.should eq("id")
        fields[0].table.should eq("contacts")
      end

      context "as raw SQL" do
        it "removes brackets" do
          field = described_class["table"].group(Contact.context.sql("some sql"))._groups![0]
          field.identifier.should eq("some sql")
        end
      end
    end

    context "with block" do
      it "yield expression builder as current context and accepts array" do
        fields = described_class["table"].group { [_f1, Contact._id] }._groups!
        fields.size.should eq(2)
        fields[0].field.should eq("f1")
        fields[0].table.should eq("table")
      end

      it "removes brackets from raw SQL" do
        field = described_class["table"].group { [sql("f1")] }._groups![0]
        field.identifier.should eq("f1")
      end
    end
  end

  describe "#limit" do
    it "sets limit" do
      Contact.all.limit(2).as_sql.should match(/LIMIT 2/m)
    end
  end

  describe "#offset" do
    it "sets offset" do
      Contact.all.offset(2).as_sql.should match(/OFFSET 2/m)
    end
  end

  describe "#from" do
    it "accepts plain query" do
      Factory.build_query(table: "contacts").from("( select * from contacts where id > 2 )").as_sql
        .should eq(%(SELECT #{quote_identifier("contacts")}.* FROM ( select * from contacts where id > 2 )))
    end

    it "accepts query object" do
      Factory.build_query(table: "contacts").from(Contact.where { _id > 2 }).as_sql
        .should eq(%(SELECT #{quote_identifier("contacts")}.* FROM ( SELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")} WHERE #{quote_identifier("contacts.id")} > %s  ) ))
    end
  end

  describe "#union" do
    it "adds query to own array of unions" do
      q = Jennifer::Query["table"]
      q.union(Jennifer::Query["table2"]).should eq(q)
      q._unions!.should_not be_empty
    end
  end

  describe "#cte" do
    describe "top level" do
      it do
        Factory.create_contact(name: "John", age: 15)
        Jennifer::Query["cte"].with("cte", Jennifer::Query["contacts"]).count.should eq(1)
      end
    end

    describe "varying query types" do
      it do
        c1 = Factory.create_contact(name: "Anton", age: 32)
        Factory.create_contact(name: "Bertha", age: 43)
        c3 = Factory.create_contact(name: "Caesar", age: 37)

        Factory.create_address(street: "Test street 1", contact_id: c1.id!)
        Factory.create_address(street: "Test street 2", contact_id: c3.id!)

        Address.all
          .with("acontacts", Contact.all.where { sql("contacts.name LIKE %s", ["A%"]) }, false)
          .join("acontacts") { _acontacts__id == _addresses__contact_id }
          .pluck(:street).should eq ["Test street 1"]
      end
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
    it "adds DISTINCT to SELECT clause" do
      Query["contacts"].select(:age).distinct.as_sql.should match(/SELECT DISTINCT #{reg_quote_identifier("contacts.age")}/)
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
      clone._order?.should be_falsey
    end

    it "excludes join if given" do
      q = Query["contacts"].join("passports") { _contact_id == _contacts__id }
      clone = q.except(["join"])
      clone._joins?.should be_nil
    end

    it "excludes join if given" do
      q = Query["contacts"].union(Query["contacts"])
      clone = q.except(["union"])
      clone._unions?.should be_falsey
    end

    it "excludes group if given" do
      q = Query["contacts"].group(:age)
      clone = q.except(["group"])
      clone._groups?.should be_falsey
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
      clone.as_sql.should_not match(/WHERE/)
    end

    it "excludes CTE if given" do
      q = Query["contacts"].with("test", Query["users"])
      clone = q.except(["cte"])
      clone.as_sql.should_not match(/WITH/)
    end

    it "expression builder follow newly created object" do
      q = Query["contacts"]
      clone = q.except([""])
      clone.expression_builder.query.should eq(clone)
    end
  end

  describe "#clone" do
    clone = Query["contacts"]
      .where { _id > 2 }
      .group(:age)
      .having { _age > 2 }
      .order(age: "asc")
      .join("passports") { _contact_id == _contacts__id }
      .union(Query["contacts"])
      .select { [_id] }
      .clone

    it { clone.as_sql.should match(/WHERE/) }
    it { clone.as_sql.should match(/GROUP/) }
    it { clone.as_sql.should match(/ORDER/) }
    it { clone.as_sql.should match(/JOIN/) }
    it { clone.as_sql.should match(/UNION/) }
    it { clone._select_fields[0].should_not be_a(Jennifer::QueryBuilder::Star) }
  end

  describe "#none" do
    context "when is used alongside with #pluck" do
      it "returns nothing when a single column is plucked" do
        expect_query_silence do
          Query["contacts"].none.pluck(:id).should be_empty
        end
      end

      it "returns nothing when multiple columns are plucked" do
        expect_query_silence do
          Query["contacts"].none.pluck(%i(id name)).should be_empty
        end
      end
    end

    context "when is used alongside with #delete" do
      it "deletes nothing" do
        expect_query_silence do
          Query["contacts"].none.delete
        end
      end
    end

    context "when is used alongside with #exists?" do
      it "returns false without hitting the db" do
        expect_query_silence do
          Query["contacts"].none.exists?.should be_false
        end
      end
    end

    context "when is used alongside with #update" do
      context "when block is given" do
        it "updates nothing" do
          expect_query_silence do
            block_is_executed = false
            Query["contacts"].none.update { block_is_executed = true; {:age => _age + 10} }
            block_is_executed.should be_true
          end
        end
      end

      context "when arguments is passed as hash" do
        it "updates nothing" do
          expect_query_silence do
            Query["contacts"].none.update({:age => 40})
          end
        end
      end
    end

    context "when is used alongside with #db_results" do
      it "returns empty array" do
        expect_query_silence do
          Query["contacts"].none.db_results.should be_empty
        end
      end
    end

    context "when is used alongside with #results" do
      it "returns empty array" do
        expect_query_silence do
          Query["contacts"].none.results.should be_empty
        end
      end
    end

    context "when is used alongside with #each_result_set" do
      it do
        expect_query_silence do
          Query["contacts"].none.each_result_set do
          end
        end
      end
    end

    context "when is used alongside with #find_records_by_sql" do
      it "return empty array" do
        expect_query_silence do
          Query["contacts"].none.find_records_by_sql("INVALID SQL").should be_empty
        end
      end
    end
  end

  describe "#merge" do
    describe "having" do
      it do
        Query["contacts"].merge(Query["users"].having { _id > 1 }).as_sql
          .should match(/HAVING #{reg_quote_identifier("users.id")} >/)
      end
    end

    describe "order" do
      it do
        Query["contacts"].merge(Query["users"].order(id: :desc)).as_sql
          .should match(/ORDER BY #{reg_quote_identifier("users.id")} DESC/)
      end
    end

    describe "join" do
      it do
        Query["contacts"].merge(Query["users"].join("addresses") { _user_id == c("id", "users") }).as_sql
          .should match(/JOIN #{reg_quote_identifier("addresses")} ON #{reg_quote_identifier("addresses.user_id")} = #{reg_quote_identifier("users.id")}/)
      end
    end

    describe "group by" do
      it do
        Query["contacts"].merge(Query["users"].group(:id)).as_sql.should match(/GROUP BY #{reg_quote_identifier("users.id")}/)
      end
    end

    describe "CTE" do
      it do
        query = Query["contacts"].with("test", Contact.all)
        Query["contacts"].merge(query)
          .as_sql
          .should match(/WITH test AS \(SELECT #{reg_quote_identifier("contacts")}\.\* FROM #{reg_quote_identifier("contacts")} \)/)
      end
    end

    describe "where" do
      it do
        Query["contacts"].merge(Query["users"].where { _id > 1 }).as_sql.should match(/WHERE #{reg_quote_identifier("users.id")} >/)
      end
    end

    describe "do nothing" do
      it do
        Query["contacts"].merge(Query["users"].none).do_nothing?.should be_true
      end
    end
  end

  describe "#to_json" do
    it "includes all fields by default" do
      Factory.create_passport
      Passport.all.to_json.should eq(%([{"enn":"dsa","contact_id":null}]))
    end

    it "allows to specify *only* argument solely" do
      Factory.create_passport
      Passport.all.to_json(%w[enn]).should eq(%([{"enn":"dsa"}]))
    end

    it "allows to specify *except* argument solely" do
      Factory.create_passport
      Passport.all.to_json(except: %w[enn]).should eq(%([{"contact_id":null}]))
    end

    context "with block" do
      it "allows to extend json using block" do
        executed = false
        Factory.create_passport
        Passport.all.to_json do |json, obj|
          executed = true
          obj.class.should eq(Passport)
          json.field "custom", "value #{obj.enn}"
        end.should eq(%([{"enn":"dsa","contact_id":null,"custom":"value dsa"}]))
        executed.should be_true
      end

      it "respects :only option" do
        Factory.create_passport
        Passport.all.to_json(%w[enn]) do |json|
          json.field "custom", "value"
        end.should eq(%([{"enn":"dsa","custom":"value"}]))
      end

      it "respects :except option" do
        Factory.create_passport
        Passport.all.to_json(except: %w[enn]) do |json|
          json.field "custom", "value"
        end.should eq(%([{"contact_id":null,"custom":"value"}]))
      end
    end
  end
end
