require "../spec_helper"

describe Jennifer::QueryBuilder::Query do
  Spec.before_each do
    Contact.all.delete
    Address.all.delete
    Passport.all.delete
  end

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

  describe "#c" do
    it "creates criteria with given field name" do
      c = query_builder.c("some field")
      c.should be_a(Jennifer::QueryBuilder::Criteria)
      c.field.should eq("some field")
    end
  end

  describe "#set_tree" do
    context "argument is another query" do
      it "gets it's tree" do
        q1 = query_builder
        q2 = query_builder
        q1.set_tree(q1.c("f1"))
        q2.set_tree(q1)
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

  describe "#join" do
    it "addes inner join by default" do
      q1 = query_builder
      q1.join(Address) { c("id") == Address.c("contact_id") }
      q1.join_clause.should match(/JOIN addresses ON test\.id = addresses\.contact_id/)
    end
  end

  describe "#left_join" do
    it "addes left join" do
      q1 = query_builder
      q1.left_join(Address) { c("id") == Address.c("contact_id") }
      q1.join_clause.should match(/LEFT JOIN addresses ON test\.id = addresses\.contact_id/)
    end
  end

  describe "#right_join" do
    it "addes right join" do
      q1 = query_builder
      q1.right_join(Address) { c("id") == Address.c("contact_id") }
      q1.join_clause.should match(/RIGHT JOIN addresses ON test\.id = addresses\.contact_id/)
    end
  end

  describe "#with" do
    it "addes to select clause given relation" do
      q1 = Contact.all
      q1.with(:addresses)
      q1.select_clause.should match(/SELECT contacts\.\*, addresses\.\*/)
    end

    it "raises error if given relation is invalid" do
      q1 = Contact.all
      q1.with(:relation)
      expect_raises(Exception, "Unknown relation relation") do
        q1.select_clause
      end
    end
  end

  describe "#incldudes" do
    pending "not added yet" { }
  end

  describe "#destroy" do
  end

  describe "#delete" do
    it "deletes from db using existing conditions" do
      count = Contact.all.count
      c = contact_create(name: "Extra content")
      Contact.all.count.should eq(count + 1)
      Contact.where { name == "Extra content" }.delete
      Contact.all.count.should eq(count)
    end
  end

  describe "#exists?" do
    pending "check if there is any row with given conditions" do
    end
  end

  describe "#count" do
    it "returns count of rows for given query" do
      contact_create(name: "Asd")
      contact_create(name: "BBB")
      Contact.where { name.like("%A%") }.count.should eq(1)
    end
  end

  describe "#uniqe" do
    pending "returns only unique values on given columns" do
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

      Contact.all.where { age == 15 }.first.not_nil!.id.should eq(c1.id)
    end

    it "returns nil if ther eis no such records" do
      Contact.all.first.should be_nil
    end
  end

  describe "#pluck" do
    context "given list of attributes" do
      it "returns array of hashes" do
        contact_create(name: "a", age: 1)
        contact_create(name: "b", age: 2)
        res = Contact.all.pluck(:name, :age)
        res.size.should eq(2)
        res[0].keys.should eq(["name", "age"])
        res[0]["name"].should eq("a")
        res[1]["age"].should eq(2)
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
  end

  describe "#update" do
    it "updates given fields in all matched rows" do
      contact_create(age: 1, name: "a")
      contact_create(age: 2, name: "a")
      contact_create(age: 3, name: "a")

      Contact.where { age < 3 }.update({:age => 10, :name => "b"})
      Contact.where { (age == 10) & (name == "b") }.count.should eq(2)
    end
  end

  describe "#select_query" do
    s = Contact.where { age == 1 }.join(Contact) { age == Contact._age }.order(age: :desc).limit(1)

    it "includes select clause" do
      s.select_query.should match(/#{Regex.escape(s.select_clause)}/)
    end

    it "includes body section" do
      s.select_query.should match(/#{Regex.escape(s.body_section)}/)
    end
  end

  describe "#select_clause" do
    s = Contact.all.join(Address) { id == Contact._id }.with(:addresses)

    it "includes from clause" do
      s.select_clause.should match(/#{Regex.escape(s.from_clause)}/)
    end
  end

  describe "#from_clause" do
    it "build correct from clause" do
      Contact.all.from_clause.should eq("FROM contacts\n")
    end
  end

  describe "#body_section" do
    s = Contact.where { age == 1 }.join(Contact) { age == Contact._age }.order(age: :desc).limit(1)

    it "includes join clause" do
      s.select_query.should match(/#{Regex.escape(s.join_clause)}/)
    end

    it "includes where clause" do
      s.select_query.should match(/#{Regex.escape(s.where_clause)}/)
    end

    it "includes order clause" do
      s.select_query.should match(/#{Regex.escape(s.order_clause)}/)
    end

    it "includes limit clause" do
      s.select_query.should match(/#{Regex.escape(s.limit_clause)}/)
    end
  end

  describe "#join_clause" do
    it "calls #to_sql on all parts" do
      res = Contact.all.join(Address) { id == Address._contact_id }
                       .join(Passport) { id == Passport._contact_id }
                       .join_clause
      res.split("JOIN").size.should eq(3)
    end
  end

  describe "#where_clause" do
    context "condition exists" do
      it "includes its sql" do
        Contact.where { id == 1 }.where_clause.should eq("WHERE contacts.id = ?\n")
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
      Contact.all.order_clause.should eq("")
    end

    it "returns all orders" do
      Contact.all.order(age: :desc, name: :asc).order_clause.should match(/ORDER BY age DESC, name ASC/)
    end
  end

  describe "#select_args" do
    it "returns array of join and condition args" do
      Contact.where { id == 2 }.join(Address) { name == "asd" }.select_args.should eq(db_array(2, "asd"))
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

    it "correctly build nested objects" do
      c1 = contact_create(name: "a")
      c2 = contact_create(name: "b")

      a1 = address_create(street: "a1", contact_id: c1.id)
      a2 = address_create(street: "a2", contact_id: c1.id)

      p = passport_create(contact_id: c2.id)

      res = Contact.all.left_join(Address) { id == Address._contact_id }
                       .left_join(Passport) { id == Passport._contact_id }
                       .with(:addresses, :passport).to_a

      res.size.should eq(2)
      res[0].addresses.size.should eq(2)
      res[1].addresses.size.should eq(0)
      res[0].passport.should be_nil
    end
  end
end
