require "../spec_helper"

describe Jennifer::QueryBuilder::Query do
  described_class = Jennifer::QueryBuilder::Query
  describe "#to_sql" do
    context "if query tree is not epty" do
      it "retruns sql representation of condition" do
        q = query_builder
        c = criteria_builder
        q.set_tree(c).to_sql.should eq(c.to_sql)
      end
    end

    context "if query tree is empty" do
      it "returns empty string" do
        query_builder.to_sql.should eq("")
      end
    end
  end

  describe "#sql_args" do
    context "if query tree is not epty" do
      it "retruns sql args of condition" do
        q = query_builder
        c = criteria_builder
        q.set_tree(c).sql_args.should eq(c.sql_args)
      end
    end

    context "if query tree is empty" do
      it "returns empty array" do
        query_builder.sql_args.should eq([] of DB::Any)
      end
    end
  end

  describe "#set_tree" do
    context "argument is another query" do
      it "gets it's tree" do
        q1 = query_builder
        q2 = query_builder
        q1.set_tree(expression_builder.c("f1"))
        q2.set_tree(q1)
        q1.tree.should be(q2.tree)
      end
    end

    context "has own tree" do
      it "makes AND with new criteria" do
        q1 = query_builder
        c1 = criteria_builder
        c2 = criteria_builder(field: "f2")

        q1.set_tree(c1)
        q1.set_tree(c2)
        q1.tree.should be_a Jennifer::QueryBuilder::And
      end
    end

    context "is empty" do
      it "makes given criteria as own" do
        q1 = query_builder
        c1 = criteria_builder

        q1.set_tree(c1)
        q1.tree.as(Jennifer::QueryBuilder::Condition).lhs.should eq(c1)
      end
    end
  end

  describe "#where" do
    it "allows to pass criteria and sets it via AND" do
      q1 = query_builder
      c = criteria_builder(field: "f1") & criteria_builder(field: "f2")
      q1.where { c("f1") & c("f2") }
      q1.tree.to_s.should match(/tests\.f1 AND tests\.f2/)
    end
  end

  describe "#join" do
    it "addes inner join by default" do
      q1 = query_builder
      q1.join(Address) { _test__id == _contact_id }
      q1.join_clause.should match(/JOIN addresses ON test\.id = addresses\.contact_id/)
    end
  end

  describe "#left_join" do
    it "addes left join" do
      q1 = query_builder
      q1.left_join(Address) { _test__id == _contact_id }
      q1.join_clause.should match(/LEFT JOIN addresses ON test\.id = addresses\.contact_id/)
    end
  end

  describe "#right_join" do
    it "addes right join" do
      q1 = query_builder
      q1.right_join(Address) { _test__id == _contact_id }
      q1.join_clause.should match(/RIGHT JOIN addresses ON test\.id = addresses\.contact_id/)
    end
  end

  describe "#having" do
    it "returns correct entities" do
      contact_create(name: "Ivan", age: 15)
      contact_create(name: "Max", age: 19)
      contact_create(name: "Ivan", age: 50)

      res = Contact.all.select("COUNT(id) as count, contacts.name").group("name").having { sql("COUNT(id)") > 1 }.pluck(:name)
      res.size.should eq(1)
      res[0].should eq("Ivan")
    end
  end

  describe "#delete" do
    it "deletes from db using existing conditions" do
      count = Contact.all.count
      c = contact_create(name: "Extra content")
      Contact.all.count.should eq(count + 1)
      described_class.new("contacts").where { _name == "Extra content" }.delete
      Contact.all.count.should eq(count)
    end
  end

  describe "#exists?" do
    it "returns true if there is such object with given condition" do
      contact_create(name: "Anton")
      described_class.new("contacts").where { _name == "Anton" }.exists?.should be_true
    end

    it "returns false if there is no such object with given condition" do
      contact_create(name: "Anton")
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
      contact_create(name: "Asd")
      contact_create(name: "BBB")
      described_class.new("contacts").where { _name.like("%A%") }.count.should eq(1)
    end
  end

  describe "#from" do
    it "accepts plain query" do
      query_builder("contacts").from("select * from contacts where id > 2")
                               .select_clause.should eq("SELECT contacts.*\nFROM ( select * from contacts where id > 2 ) ")
    end

    it "accepts query object" do
      query_builder("contacts").from(Contact.where { _id > 2 })
                               .select_clause.should eq("SELECT contacts.*\nFROM ( SELECT contacts.*\nFROM contacts\nWHERE contacts.id > %s\n ) ")
    end
  end

  describe "#max" do
    it "returns maximum value" do
      contact_create(name: "Asd")
      contact_create(name: "BBB")
      described_class.new("contacts").max(:name, String).should eq("BBB")
    end
  end

  describe "#min" do
    it "returns minimum value" do
      contact_create(name: "Asd", age: 19)
      contact_create(name: "BBB", age: 20)
      described_class.new("contacts").min(:age, Int32).should eq(19)
    end
  end

  describe "#sum" do
    it "returns sum value" do
      contact_create(name: "Asd", age: 20)
      contact_create(name: "BBB", age: 19)
      {% if env("DB") == "mysql" %}
        described_class.new("contacts").sum(:age, Float64).should eq(39)
      {% else %}
        described_class.new("contacts").sum(:age, Int64).should eq(39i64)
      {% end %}
    end
  end

  describe "#avg" do
    it "returns average value" do
      contact_create(name: "Asd", age: 20)
      contact_create(name: "BBB", age: 35)
      {% if env("DB") == "mysql" %}
        described_class.new("contacts").avg(:age, Float64).should eq(27.5)
      {% else %}
        described_class.new("contacts").avg(:age, PG::Numeric).should eq(27.5)
      {% end %}
    end
  end

  describe "#group_max" do
    it "returns array of maximum values" do
      contact_create(name: "Asd", gender: "male", age: 18)
      contact_create(name: "BBB", gender: "female", age: 19)
      contact_create(name: "Asd", gender: "male", age: 20)
      contact_create(name: "BBB", gender: "female", age: 21)
      match_array(described_class.new("contacts").group(:gender).group_max(:age, Int32), [20, 21])
    end
  end

  describe "#group_min" do
    it "returns minimum value" do
      contact_create(name: "Asd", gender: "male", age: 18)
      contact_create(name: "BBB", gender: "female", age: 19)
      contact_create(name: "Asd", gender: "male", age: 20)
      contact_create(name: "BBB", gender: "female", age: 21)
      match_array(described_class.new("contacts").group(:gender).group_min(:age, Int32), [18, 19])
    end
  end

  describe "#group_sum" do
    it "returns sum value" do
      contact_create(name: "Asd", gender: "male", age: 18)
      contact_create(name: "BBB", gender: "female", age: 19)
      contact_create(name: "Asd", gender: "male", age: 20)
      contact_create(name: "BBB", gender: "female", age: 21)
      {% if env("DB") == "mysql" %}
        match_array(described_class.new("contacts").group(:gender).group_sum(:age, Float64), [38.0, 40.0])
      {% else %}
        match_array(described_class.new("contacts").group(:gender).group_sum(:age, Int64), [38i64, 40i64])
      {% end %}
    end
  end

  describe "#group_avg" do
    it "returns average value" do
      contact_create(name: "Asd", gender: "male", age: 18)
      contact_create(name: "BBB", gender: "female", age: 19)
      contact_create(name: "Asd", gender: "male", age: 20)
      contact_create(name: "BBB", gender: "female", age: 21)
      {% if env("DB") == "mysql" %}
        match_each([19, 20], described_class.new("contacts").group(:gender).group_avg(:age, Float64))
      {% else %}
        match_each([19, 20], described_class.new("contacts").group(:gender).group_avg(:age, PG::Numeric))
      {% end %}
    end
  end

  # TODO: move other plain query methods here
end
