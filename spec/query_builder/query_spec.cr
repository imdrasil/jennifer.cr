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

  describe "#where" do
    it "allows to pass criteria and sets it via AND" do
      q1 = Factory.build_query
      c = Factory.build_criteria(field: "f1") & Factory.build_criteria(field: "f2")
      q1.where { c("f1") & c("f2") }
      q1.tree.to_s.should match(/tests\.f1 AND tests\.f2/)
    end
  end

  describe "#join" do
    it "addes inner join by default" do
      q1 = Factory.build_query
      q1.join(Address) { _test__id == _contact_id }
      q1._joins.map(&.type).should eq([:inner])
    end
  end

  describe "#left_join" do
    it "addes left join" do
      q1 = Factory.build_query
      q1.left_join(Address) { _test__id == _contact_id }
      q1._joins.map(&.type).should eq([:left])
    end
  end

  describe "#right_join" do
    it "addes right join" do
      q1 = Factory.build_query
      q1.right_join(Address) { _test__id == _contact_id }
      q1._joins.map(&.type).should eq([:right])
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
  end

  describe "#delete" do
    it "deletes from db using existing conditions" do
      count = Contact.all.count
      c = Factory.create_contact(name: "Extra content")
      Contact.all.count.should eq(count + 1)
      described_class.new("contacts").where { _name == "Extra content" }.delete
      Contact.all.count.should eq(count)
    end
  end

  describe "#exists?" do
    it "returns true if there is such object with given condition" do
      Factory.create_contact(name: "Anton")
      described_class.new("contacts").where { _name == "Anton" }.exists?.should be_true
    end

    it "returns false if there is no such object with given condition" do
      Factory.create_contact(name: "Anton")
      described_class.new("contacts").where { _name == "Jhon" }.exists?.should be_false
    end
  end

  describe "#limit" do
    pending "sets @limit" do
    end
  end

  describe "#offset" do
    pending "sets @offset" do
    end
  end

  describe "#count" do
    it "returns count of rows for given query" do
      Factory.create_contact(name: "Asd")
      Factory.create_contact(name: "BBB")
      described_class.new("contacts").where { _name.like("%A%") }.count.should eq(1)
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

  describe "#max" do
    it "returns maximum value" do
      Factory.create_contact(name: "Asd")
      Factory.create_contact(name: "BBB")
      described_class.new("contacts").max(:name, String).should eq("BBB")
    end
  end

  describe "#min" do
    it "returns minimum value" do
      Factory.create_contact(name: "Asd", age: 19)
      Factory.create_contact(name: "BBB", age: 20)
      described_class.new("contacts").min(:age, Int32).should eq(19)
    end
  end

  describe "#sum" do
    it "returns sum value" do
      Factory.create_contact(name: "Asd", age: 20)
      Factory.create_contact(name: "BBB", age: 19)
      {% if env("DB") == "mysql" %}
        described_class.new("contacts").sum(:age, Float64).should eq(39)
      {% else %}
        described_class.new("contacts").sum(:age, Int64).should eq(39i64)
      {% end %}
    end
  end

  describe "#avg" do
    it "returns average value" do
      Factory.create_contact(name: "Asd", age: 20)
      Factory.create_contact(name: "BBB", age: 35)
      {% if env("DB") == "mysql" %}
        described_class.new("contacts").avg(:age, Float64).should eq(27.5)
      {% else %}
        described_class.new("contacts").avg(:age, PG::Numeric).should eq(27.5)
      {% end %}
    end
  end

  describe "#group_max" do
    it "returns array of maximum values" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 19)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      Factory.create_contact(name: "BBB", gender: "female", age: 21)
      match_array(described_class.new("contacts").group(:gender).group_max(:age, Int32), [20, 21])
    end
  end

  describe "#group_min" do
    it "returns minimum value" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 19)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      Factory.create_contact(name: "BBB", gender: "female", age: 21)
      match_array(described_class.new("contacts").group(:gender).group_min(:age, Int32), [18, 19])
    end
  end

  describe "#group_sum" do
    it "returns sum value" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 19)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      Factory.create_contact(name: "BBB", gender: "female", age: 21)
      {% if env("DB") == "mysql" %}
        match_array(described_class.new("contacts").group(:gender).group_sum(:age, Float64), [38.0, 40.0])
      {% else %}
        match_array(described_class.new("contacts").group(:gender).group_sum(:age, Int64), [38i64, 40i64])
      {% end %}
    end
  end

  describe "#group_avg" do
    it "returns average value" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 19)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      Factory.create_contact(name: "BBB", gender: "female", age: 21)
      {% if env("DB") == "mysql" %}
        match_each([19, 20], described_class.new("contacts").group(:gender).group_avg(:age, Float64))
      {% else %}
        match_each([19, 20], described_class.new("contacts").group(:gender).group_avg(:age, PG::Numeric))
      {% end %}
    end
  end

  describe "#group_count" do
    it "returns count of each group elements" do
      Factory.create_contact(name: "Asd", gender: "male", age: 18)
      Factory.create_contact(name: "BBB", gender: "female", age: 18)
      Factory.create_contact(name: "Asd", gender: "male", age: 20)
      match_each([2, 1], described_class.new("contacts").group(:age).group_count(:age))
    end
  end

  describe "#increment" do
    it "accepts hash" do
      c = Factory.create_contact(name: "asd", gender: "male", age: 18)
      Contact.where { _id == c.id }.increment({:age => 2})
      Contact.find!(c.id).age.should eq(20)
    end

    it "accepts named tuple literal" do
      c = Factory.create_contact(name: "asd", gender: "male", age: 18)
      Contact.where { _id == c.id }.increment(age: 2)
      Contact.find!(c.id).age.should eq(20)
    end
  end

  describe "#decrement" do
    it "accepts hash" do
      c = Factory.create_contact(name: "asd", gender: "male", age: 20)
      Contact.where { _id == c.id }.decrement({:age => 2})
      Contact.find!(c.id).age.should eq(18)
    end

    it "accepts named tuple literal" do
      c = Factory.create_contact({:name => "asd", :gender => "male", :age => 20})
      Contact.where { _id == c.id }.decrement(age: 2)
      Contact.find!(c.id).age.should eq(18)
    end
  end

  describe "#results" do
    it "returns array of records" do
      r = Contact.all.results.should eq([] of Jennifer::Record)
    end
  end

  describe "#union" do
    it "adds query to own array of unions" do
      q = Jennifer::Query["table"]
      q.union(Jennifer::Query["table2"]).should eq(q)
      q._unions.empty?.should be_false
    end
  end

  describe "#to_a" do
    context "none was called" do
      it "doesn't hit db and return empty array" do
        count = query_count
        result = Jennifer::Query["contacts"].none.to_a
        query_count.should eq(count)
        result.empty?.should be_true
      end
    end
  end

  # TODO: move other plain query methods here
end
