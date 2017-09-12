require "../spec_helper"

# TODO: add checking for log entries when we shouldn't hit db

describe Jennifer::QueryBuilder::ModelQuery do
  describe "#with" do
    it "addes to select clause given relation" do
      q1 = Contact.all.relation(:addresses)
      q1.with(:addresses)
      select_clause(q1).should match(/SELECT contacts\.\*, addresses\.\*/)
    end

    it "raises error if given relation is not exists" do
      q1 = Contact.all
      expect_raises(Jennifer::UnknownRelation, "Unknown relation for Contact: relation") do
        q1.with(:relation)
        select_clause(q1)
      end
    end

    it "raises error if given relation is not joined" do
      expect_raises(Jennifer::BaseException, /with should be called after correspond join: no such table/) do
        select_clause(Contact.all.with(:addresses))
      end
    end
  end

  describe "#includes" do
    it "loads relation as well" do
      c1 = Factory.create_contact(name: "asd")
      Factory.create_address(contact_id: c1.id, street: "asd st.")
      res = Contact.all.includes(:addresses).first!
      res.addresses[0].street.should eq("asd st.")
    end

    context "target class defines not all fields and has non strict mapping" do
      it "loads both target class fields and included ones" do
        contacts = Factory.create_contact(3)
        ids = contacts.map(&.id)
        Factory.create_address(contact_id: contacts[0].id)
        res = ContactWithDependencies.all.includes(:addresses).where { _id.in(ids) }.order("contacts.id": :asc).to_a
        res.size.should eq(3)
        res[0].addresses.size.should eq(1)
        res[0].name.nil?.should be_false
      end
    end

    context "related model has own request" do
      # TODO: move it to SqlGenerator
      it "it generates proper request" do
        contact = Factory.create_contact
        query = Contact.all.includes(:main_address)
        Jennifer::Adapter::SqlGenerator.select(query).should match(/addresses\.main/)
      end
    end

    pending "with aliases" do
    end
  end

  describe "#relation" do
    # TODO: refactor this bad test - this should be tested under sql generating process
    it "makes join using relation scope" do
      ::Jennifer::Adapter::SqlGenerator
        .select(Contact.all.relation(:addresses))
        .should match(/LEFT JOIN addresses ON addresses.contact_id = contacts.id/)
    end
  end

  describe "#destroy" do
    pending "add" do
    end
  end

  describe "#first" do
    it "returns first record" do
      c1 = Factory.create_contact(age: 15)
      c2 = Factory.create_contact(age: 15)

      r = Contact.all.first
      r.not_nil!.id.should eq(c1.id)
    end

    it "returns nil if there is no such records" do
      Contact.all.first.should be_nil
    end
  end

  describe "#first!" do
    it "returns first record" do
      c1 = Factory.create_contact(age: 15)
      c2 = Factory.create_contact(age: 15)

      r = Contact.all.first!
      r.id.should eq(c1.id)
    end

    it "raises error if there is no such records" do
      expect_raises(Jennifer::RecordNotFound) do
        Contact.all.first!
      end
    end
  end

  describe "#last" do
    it "inverse all orders" do
      c1 = Factory.create_contact(age: 15)
      c2 = Factory.create_contact(age: 16)

      r = Contact.all.order(age: :desc).last!
      r.id.should eq(c1.id)
    end

    it "add order by primary key if no order was specified" do
      c1 = Factory.create_contact(age: 15)
      c2 = Factory.create_contact(age: 16)

      r = Contact.all.last!
      r.id.should eq(c2.id)
    end
  end

  describe "#pluck" do
    context "given list of attributes" do
      it "returns array of arrays" do
        Factory.create_contact(name: "a", age: 13)
        Factory.create_contact(name: "b", age: 14)
        res = Contact.all.pluck(:name, :age)
        res.size.should eq(2)
        res[0][0].should eq("a")
        res[1][1].should eq(14)
      end
    end

    context "given one argument" do
      it "correctly extracts json" do
        Factory.create_address(details: JSON.parse({:city => "Duplin"}.to_json))
        Address.all.pluck(:details)[0].should be_a(JSON::Any)
      end

      it "accepts plain sql" do
        Factory.create_contact(name: "a", age: 13)
        res = Contact.all.select("COUNT(id) + 1 as test").pluck(:test)
        res[0].should eq(2)
      end

      pending "properly works with #with" do
      end
    end

    context "given array of attributes" do
      it "returns array of arrays" do
        Factory.create_contact(name: "a", age: 13)
        Factory.create_contact(name: "b", age: 14)
        res = Contact.all.pluck([:name, :age])
        res.size.should eq(2)
        res[0][0].should eq("a")
        res[1][1].should eq(14)
      end
    end
  end

  describe "#order" do
    context "using named tuple" do
      it "correctly sorts" do
        Factory.create_contact(age: 13)
        Factory.create_contact(age: 14)

        Contact.all.order(age: :desc).first!.age.should eq(14)
        Contact.all.order(age: :asc).first!.age.should eq(13)
      end
    end

    context "using hash" do
      it "correctly sorts" do
        Factory.create_contact(age: 13)
        Factory.create_contact(age: 14)

        Contact.all.order({:age => :desc}).first!.age.should eq(14)
        Contact.all.order({:age => :asc}).first!.age.should eq(13)
      end
    end
  end

  describe "#distinct" do
    it "returns correct names" do
      Factory.create_contact(name: "a1")
      Factory.create_contact(name: "a2")
      Factory.create_contact(name: "a1")

      r = Contact.all.order(name: :asc).distinct("name")
      r.should eq(["a1", "a2"])
    end

    pending "using table as argument" do
    end
  end

  describe "#group_by" do
    context "given column" do
      it "returns unique values by given field" do
        Factory.create_contact(name: "a1")
        Factory.create_contact(name: "a2")
        Factory.create_contact(name: "a1")

        r = Contact.all.group("name").pluck(:name)
        r.size.should eq(2)
        r.should contain("a1")
        r.should contain("a2")
      end
    end

    context "given columns" do
      it "returns unique values by given field" do
        c1 = Factory.create_contact(name: "a1", age: 29)
        c2 = Factory.create_contact(name: "a2", age: 29)
        c3 = Factory.create_contact(name: "a1", age: 29)
        a1 = Factory.create_address(street: "asd st.", contact_id: c1.id)
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
      Factory.create_contact(age: 13, name: "a")
      Factory.create_contact(age: 14, name: "a")
      Factory.create_contact(age: 15, name: "a")

      Contact.where { _age < 15 }.update({:age => 20, :name => "b"})
      Contact.where { (_age == 20) & (_name == "b") }.count.should eq(2)
    end
  end

  describe "#select_args" do
    it "returns array of join and condition args" do
      Contact.where { _id == 2 }.join(Address) { _name == "asd" }.select_args.should eq(db_array("asd", 2))
    end
  end

  describe "#each" do
    it "yields each found row" do
      Factory.create_contact(name: "a", age: 13)
      Factory.create_contact(name: "b", age: 14)
      i = 13
      Contact.all.order(age: :asc).each do |c|
        c.age.should eq(i)
        i += 1
      end
      i.should eq(15)
    end
  end

  describe "#each_result_set" do
    it "yields rows from result set" do
      Factory.create_contact(name: "a", age: 13)
      Factory.create_contact(name: "b", age: 14)

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
      Factory.create_contact(name: "a", age: 13)
      Factory.create_contact(name: "b", age: 14)
      res = Contact.all.to_a

      res.should be_a Array(Contact)
      res.size.should eq(2)
    end

    context "with nested objects" do
      it "builds nested objects" do
        c2 = Factory.create_contact(name: "b")
        p = Factory.create_passport(contact_id: c2.id, enn: "12345")
        res = Passport.all.join(Contact) { _id == _passport__contact_id }.with(:contact).first!

        res.contact!.name.should eq("b")
      end

      context "none was called" do
        it "doesn't hit db and return empty array" do
          count = query_count
          result = Contact.all.includes(:addresses).none.to_a
          query_count.should eq(count)
          result.empty?.should be_true
        end
      end

      context "when some records have no nested objects" do
        it "correctly build nested objects" do
          c1 = Factory.create_contact(name: "a")
          c2 = Factory.create_contact(name: "b")

          a1 = Factory.create_address(street: "a1 st.", contact_id: c1.id)
          a2 = Factory.create_address(street: "a2 st.", contact_id: c1.id)

          p = Factory.create_passport(contact_id: c2.id, enn: "12345")

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
          c1 = Factory.create_contact(name: "a")
          c2 = Factory.create_contact(name: "b")

          a1 = Factory.create_address(main: false, contact_id: c1.id)
          a2 = Factory.create_address(main: false, contact_id: c1.id)
          a3 = Factory.create_address(main: true, contact_id: c1.id)

          q = Contact.all.includes(:addresses, :main_address)
          r = q.to_a
          r.size.should eq(2)
          r[0].addresses.size.should eq(3)
          r[0].main_address.nil?.should be_false
        end
      end
    end

    context "with preload" do
      it "loads all preloaded relations" do
        contacts = Factory.create_contact(3)
        a1 = Factory.create_address(contact_id: contacts[0].id)
        a2 = Factory.create_address(contact_id: contacts[1].id)
        f = Factory.create_facebook_profile(contact_id: contacts[1].id)
        res = Contact.all.preload(:addresses, :facebook_profiles).where { _id.in(contacts[0..1].map(&.id)) }.to_a

        res.size.should eq(2)
        match_array(res[0].addresses.map(&.id), [a1.id])
        match_array(res[1].addresses.map(&.id), [a2.id])
        match_array(res[1].facebook_profiles.map(&.id), [f.id])

        res[0].facebook_profiles.empty?.should be_true
      end
    end

    context "none was called" do
      it "doesn't hit db and return empty array" do
        count = query_count
        result = Jennifer::Query["contacts"].none.to_a
        query_count.should eq(count)
        result.empty?.should be_true
      end
    end
  end

  describe "#preload" do
    it "doesn't add JOIN condition" do
      Contact.all.preload(:address)._joins.empty?.should be_true
    end
  end
end
