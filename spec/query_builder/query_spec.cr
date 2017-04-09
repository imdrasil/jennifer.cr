require "../spec_helper"

# TODO: add checking for log entries when we shouldn't hit db

describe Jennifer::QueryBuilder::Query do
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
        q1.tree.should eq(c1 & c2)
      end
    end

    context "is empty" do
      it "makes given criteria as own" do
        q1 = query_builder
        c1 = criteria_builder

        q1.set_tree(c1)
        q1.tree.should eq(c1)
      end
    end
  end

  describe "#where" do
    it "allows to path criteria and sets via AND" do
      q1 = query_builder
      c = criteria_builder(field: "f1") & criteria_builder(field: "f2")
      q1.where { c("f1") & c("f2") }
      q1.tree.should eq(c)
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

  describe "#with" do
    it "addes to select clause given relation" do
      q1 = Contact.all.relation(:addresses)
      q1.with(:addresses)
      q1.select_clause.should match(/SELECT contacts\.\*, addresses\.\*/)
    end

    it "raises error if given relation is not exists" do
      q1 = Contact.all
      expect_raises(Jennifer::UnknownRelation, "Unknown relation for Contact: relation") do
        q1.with(:relation)
        q1.select_clause
      end
    end

    it "raises error if given relation is not joined" do
      q1 = Contact.all
      expect_raises(Jennifer::BaseException, /with should be called after correspond join: no such table/) do
        q1.with(:addresses)
        q1.select_clause
      end
    end
  end

  describe "#includes" do
    it "loads relation as well" do
      c1 = contact_create(name: "asd")
      address_create(contact_id: c1.id, street: "asd asd")

      res = Contact.all.includes(:addresses).first!
      res.addresses[0].street.should eq("asd asd")
    end
  end

  describe "#relation" do
    it "makes join using relation scope" do
      Contact.all.relation(:addresses).join_clause.should match(/JOIN addresses ON addresses.contact_id = contacts.id/)
    end

    context "with block" do
      it "adds block result to JOIN clause" do
        Contact.all.relation(:addresses) { _id > 1 }.join_clause.should match(/\(addresses.contact_id = contacts.id AND addresses.id >/)
      end
    end
  end

  describe "#destroy" do
  end

  describe "#delete" do
    it "deletes from db using existing conditions" do
      count = Contact.all.count
      c = contact_create(name: "Extra content")
      Contact.all.count.should eq(count + 1)
      Contact.where { _name == "Extra content" }.delete
      Contact.all.count.should eq(count)
    end
  end

  describe "#exists?" do
    it "returns true if there is such object with given condition" do
      contact_create(name: "Anton")
      Contact.where { _name == "Anton" }.exists?.should be_true
    end

    it "returns false if there is no such object with given condition" do
      contact_create(name: "Anton")
      Contact.where { _name == "Jhon" }.exists?.should be_false
    end
  end

  describe "#count" do
    it "returns count of rows for given query" do
      contact_create(name: "Asd")
      contact_create(name: "BBB")
      Contact.where { _name.like("%A%") }.count.should eq(1)
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

  describe "#first" do
    it "returns first record" do
      c1 = contact_create(age: 15)
      c2 = contact_create(age: 15)

      r = Contact.all.where { _age == 15 }.first!
      r.id.should eq(c1.id)
    end

    it "returns nil if ther eis no such records" do
      Contact.all.first.should be_nil
    end
  end

  describe "#last" do
    it "inverse all orders" do
      c1 = contact_create(age: 15)
      c2 = contact_create(age: 16)

      r = Contact.all.order(age: :desc).last!
      r.id.should eq(c1.id)
    end

    it "add order by primary key if no order was specified" do
      c1 = contact_create(age: 15)
      c2 = contact_create(age: 16)

      r = Contact.all.last!
      r.id.should eq(c2.id)
    end
  end

  describe "#pluck" do
    context "given list of attributes" do
      it "returns array of arrays" do
        contact_create(name: "a", age: 1)
        contact_create(name: "b", age: 2)
        res = Contact.all.pluck(:name, :age)
        res.size.should eq(2)
        res[0][0].should eq("a")
        res[1][1].should eq(2)
      end

      it "correctly extracts json" do
        address_create(details: JSON.parse({:city => "Duplin"}.to_json))
        Address.all.pluck(:details)[0].should be_a(JSON::Any)
      end

      it "accepts plain sql" do
        contact_create(name: "a", age: 1)
        res = Contact.all.select("COUNT(id) + 1 as test").pluck(:test)
        res[0].should eq(2)
      end

      pending "properly works with #with" do
      end
    end
  end

  describe "#order" do
    context "using named tuple" do
      it "correctly sorts" do
        contact_create(age: 1)
        contact_create(age: 2)

        Contact.all.order(age: :desc).first!.age.should eq(2)
        Contact.all.order(age: :asc).first!.age.should eq(1)
      end
    end

    context "using hash" do
      it "correctly sorts" do
        contact_create(age: 1)
        contact_create(age: 2)

        Contact.all.order({:age => :desc}).first!.age.should eq(2)
        Contact.all.order({:age => :asc}).first!.age.should eq(1)
      end
    end
  end

  describe "#distinct" do
    it "returns correct names" do
      contact_create(name: "a1")
      contact_create(name: "a2")
      contact_create(name: "a1")

      r = Contact.all.distinct("name")
      r.should eq(["a1", "a2"])
    end

    pending "using table as argument" do
    end
  end

  describe "#group_by" do
    context "given column" do
      it "returns unique values by given field" do
        contact_create(name: "a1")
        contact_create(name: "a2")
        contact_create(name: "a1")

        r = Contact.all.group("name").pluck(:name)
        r.size.should eq(2)
        r[0].should eq("a1")
        r[1].should eq("a2")
      end
    end

    context "given columns" do
      it "returns unique values by given field" do
        c1 = contact_create(name: "a1", age: 29)
        c2 = contact_create(name: "a2", age: 29)
        c3 = contact_create(name: "a1", age: 29)
        a1 = address_create(street: "asd", contact_id: c1.id)
        r = Contact.all.group("name", "age").pluck(:name, :age)
        r.size.should eq(2)
        r[0][0].should eq("a1")
        r[0][1].should eq(29)

        r[1][0].should eq("a2")
        r[1][1].should eq(29)
      end
    end

    context "given named tuple" do
      pending "returns unique values by given field and tables" do
      end
    end
  end

  describe "#update" do
    it "updates given fields in all matched rows" do
      contact_create(age: 1, name: "a")
      contact_create(age: 2, name: "a")
      contact_create(age: 3, name: "a")

      Contact.where { _age < 3 }.update({:age => 10, :name => "b"})
      Contact.where { (_age == 10) & (_name == "b") }.count.should eq(2)
    end
  end

  describe "#select_query" do
    s = Contact.where { _age == 1 }.join(Contact) { _age == Contact._age }.order(age: :desc).limit(1)

    it "includes select clause" do
      s.select_query.should match(/#{Regex.escape(s.select_clause)}/)
    end

    it "includes body section" do
      s.select_query.should match(/#{Regex.escape(s.body_section)}/)
    end
  end

  describe "#select_clause" do
    s = Contact.all.join(Address) { _id == Contact._id }.with(:addresses)

    it "includes from clause" do
      s.select_clause.should match(/#{Regex.escape(String.build { |io| s.from_clause(io) })}/)
    end
  end

  describe "#from_clause" do
    it "build correct from clause" do
      String.build { |io| Contact.all.from_clause(io) }.should eq("FROM contacts\n")
    end
  end

  describe "#body_section" do
    s = Contact.where { _age == 1 }.join(Contact) { _age == Contact._age }.order(age: :desc).limit(1)

    it "includes join clause" do
      s.select_query.should match(/#{Regex.escape(s.join_clause)}/)
    end

    it "includes where clause" do
      s.select_query.should match(/#{Regex.escape(s.where_clause)}/)
    end

    it "includes order clause" do
      body = String.build { |q| s.order_clause(q) }
      s.select_query.should match(/#{Regex.escape(body)}/)
    end

    it "includes limit clause" do
      s.select_query.should match(/#{Regex.escape(s.limit_clause)}/)
    end

    pending "includes group_clause" do
    end
  end

  describe "#group_clause" do
    pending "correctly generates sql" do
    end
  end

  describe "#join_clause" do
    it "calls #to_sql on all parts" do
      res = Contact.all.join(Address) { _id == Address._contact_id }
                       .join(Passport) { _id == Passport._contact_id }
                       .join_clause
      res.split("JOIN").size.should eq(3)
    end
  end

  describe "#where_clause" do
    context "condition exists" do
      it "includes its sql" do
        Contact.where { _id == 1 }.where_clause.should eq("WHERE contacts.id = %s\n")
      end
    end

    context "conditions are empty" do
      it "returns empty string" do
        Contact.all.where_clause.should eq("")
      end
    end
  end

  describe "#limit_clause" do
    it "includes limit if is set" do
      Contact.all.limit(2).limit_clause.should match(/LIMIT 2/)
    end

    it "includes offset if it is set" do
      Contact.all.offset(4).limit_clause.should match(/OFFSET 4/)
    end
  end

  describe "#order_clause" do
    it "returns empty string if there is no orders" do
      String.build do |s|
        Contact.all.order_clause(s)
      end.should eq("")
    end

    it "returns all orders" do
      String.build do |s|
        Contact.all.order(age: :desc, name: :asc).order_clause(s)
      end.should match(/ORDER BY age DESC, name ASC/)
    end
  end

  describe "#select_args" do
    it "returns array of join and condition args" do
      Contact.where { _id == 2 }.join(Address) { _name == "asd" }.select_args.should eq(db_array(2, "asd"))
    end
  end

  describe "#each" do
    it "yields each found row" do
      contact_create(name: "a", age: 1)
      contact_create(name: "b", age: 2)
      i = 1

      Contact.all.each do |c|
        c.age.should eq(i)
        i += 1
      end
      i.should eq(3)
    end
  end

  describe "#each_result_set" do
    it "yields rows from result set" do
      contact_create(name: "a", age: 1)
      contact_create(name: "b", age: 2)

      i = 0
      Contact.all.each_result_set do |rs|
        rs.should be_a DB::ResultSet
        Contact.new(rs)
        i += 1
      end
      i.should eq(2)
    end
  end

  describe "#to_a" do
    it "retruns array of models" do
      contact_create(name: "a", age: 1)
      contact_create(name: "b", age: 2)
      res = Contact.all.to_a

      res.should be_a Array(Contact)
      res.size.should eq(2)
    end

    context "with nested objects" do
      it "builds nested objects" do
        c2 = contact_create(name: "b")
        p = passport_create(contact_id: c2.id, enn: "12345")
        res = Passport.all.join(Contact) { _id == _passport__contact_id }.with(:contact).first!

        res.contact!.name.should eq("b")
      end
      context "when some records have no nested objects" do
        it "correctly build nested objects" do
          c1 = contact_create(name: "a")
          c2 = contact_create(name: "b")

          a1 = address_create(street: "a1", contact_id: c1.id)
          a2 = address_create(street: "a2", contact_id: c1.id)

          p = passport_create(contact_id: c2.id, enn: "12345")

          res = Contact.all.left_join(Address) { _contact_id == _contact__id }
                           .left_join(Passport) { _contact_id == _contact__id }
                           .order("contacts.id": :asc)
                           .with(:addresses, :passport).to_a

          res.size.should eq(2)

          res[0].addresses.size.should eq(2)
          res[1].addresses.size.should eq(0)
          res[0].passport.should be_nil
        end
      end

      context "retrieving several relation from same table" do
        it "uses auto aliasing" do
          c1 = contact_create(name: "a")
          c2 = contact_create(name: "b")

          a1 = address_create(main: false, street: "a1", contact_id: c1.id)
          a2 = address_create(main: false, street: "a2", contact_id: c1.id)
          a3 = address_create(main: true, street: "a2", contact_id: c1.id)

          q = Contact.all.includes(:addresses, :main_address)
          r = q.to_a
          r.size.should eq(1)
          r[0].addresses.size.should eq(3)
          r[0].main_address.nil?.should be_false
        end
      end
    end
  end
end
