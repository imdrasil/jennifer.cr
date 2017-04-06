require "../spec_helper"

describe Jennifer::Model::Base do
  context "data types" do
    describe "JSON" do
      it "properly loads json field" do
        c = address_create(street: "a", details: JSON.parse(%(["a", "b", 1])))
        c = Address.find!(c.id)
        c.details.should be_a(JSON::Any)
        c.details![2].as_i.should eq(1)
      end
    end
  end

  describe "::field_count" do
    it "returns correct number of model fields" do
      Contact.field_count.should eq(4)
    end
  end

  describe "attribute getter" do
    it "provides getters" do
      c = contact_build(name: "a")
      c.name.should eq("a")
    end
  end

  describe "attribute setter" do
    it "provides setters" do
      c = contact_build(name: "a")
      c.name = "b"
      c.name.should eq("b")
    end
  end

  describe "criteria attribute class shortcut" do
    it "adds criteria shortcut for class" do
      c = Contact._name
      c.table.should eq("contacts")
      c.field.should eq("name")
    end
  end

  describe "query criteria attribute shortcut" do
    it "adds shortcut to query generator" do
      c = Contact.where { _name == "a" }.tree.as(Jennifer::QueryBuilder::Criteria)
      c.table.should eq("contacts")
      c.field.should eq("name")
    end
  end

  describe "#primary" do
    context "defaul primary field" do
      it "returns id valud" do
        c = contact_build
        c.id = -1
        c.primary.should eq(-1)
      end
    end

    context "custom field" do
      it "returns valud of custom primary field" do
        p = passport_build
        p.enn = "1qaz"
        p.primary.should eq("1qaz")
      end
    end
  end

  describe "#changed?" do
    it "returns true if at list one field was changed" do
      c = contact_build
      c.name = "new name"
      c.changed?.should be_true
    end

    it "returns false if no one field was changed" do
      contact_build.changed?.should be_false
    end
  end

  describe "::primary" do
    it "return criteria with primary key" do
      c = Passport.primary
      c.table.should eq("passports")
      c.field.should eq("enn")
    end
  end

  describe "::primary_field_name" do
    it "returns name of custom primary field" do
      Passport.primary_field_name.should eq("enn")
    end

    it "returns name of default primary field name" do
      Contact.primary_field_name.should eq("id")
    end
  end

  describe "::primary_field_type" do
    it "returns type of custom primary field" do
      Passport.primary_field_type.should eq(String)
    end

    it "returns type of default primary field name" do
      Contact.primary_field_type.should eq(Int32)
    end
  end

  describe "#init_primary_field" do
    it "sets primary field" do
      c = contact_build
      c.init_primary_field(1)
      c.primary.should eq(1)
    end

    it "raises error if it is set" do
      c = contact_build
      c.init_primary_field(1)
      expect_raises(Exception, "Primary field is already initialized") do
        c.init_primary_field(1)
      end
    end
  end

  describe "#initialize" do
    context "from result set" do
      pending "properly creates object" do
      end
    end

    context "from hash" do
      pending "properly creates object" do
      end
    end

    context "from tuple" do
      pending "properly creates object" do
      end
    end
  end

  describe "#new_record?" do
    it "returns true if mrimary field nil" do
      contact_build.new_record?.should be_true
    end

    it "returns false if primary field is not nil" do
      contact_create.new_record?.should be_false
    end
  end

  describe "::create" do
    context "from hash" do
      pending "properly creates object" do
      end
    end

    context "from tuple" do
      pending "properly creates object" do
      end
    end
  end

  describe "#save" do
    pending "saves new object to db" do
    end

    context "updates existing object in db" do
      it "stores changed fields to db" do
        c = contact_create
        c.name = "new name"
        c.save
        Contact.find!(c.id).name.should eq("new name")
      end

      it "returns true if record was saved" do
        c = contact_create
        c.name = "new name"
        c.save.should be_true
      end

      it "returns false if record wasn't saved" do
        contact_create.save.should be_false
      end

      it "calls after_save_callback" do
        c = contact_create
        c.name = "new name"
        c.save
        c.name_changed?.should be_false
      end
    end
  end

  describe "#attribute" do
    it "returns attribute value by given name" do
      c = contact_build(name: "Jessy")
      c.attribute("name").should eq("Jessy")
      c.attribute(:name).should eq("Jessy")
    end
  end

  describe "#arguments_to_save" do
    it "returns named tuple with correct keys" do
      c = contact_build
      c.name = "some another name"
      r = c.arguments_to_save
      r.is_a?(NamedTuple).should be_true
      r.keys.should eq({:args, :fields})
    end

    it "returns tuple with empty arguments if no field was changed" do
      r = contact_build.arguments_to_save
      r[:args].empty?.should be_true
      r[:fields].empty?.should be_true
    end

    it "returns tuple with changed arguments" do
      c = contact_build
      c.name = "some new name"
      r = c.arguments_to_save
      r[:args].should eq(db_array("some new name"))
      r[:fields].should eq(db_array("name"))
    end
  end

  describe "#to_h" do
  end

  describe "#attribute_hash" do
  end

  describe "::table_name" do
  end

  describe "::c" do
  end

  describe "#id" do
  end

  describe "scope macro" do
    it "executes in query context" do
      String.build { |io| Contact.all.ordered.order_clause(io) }.should match(/ORDER BY name ASC/)
    end

    context "without arguemnt" do
      it "is accessible from query object" do
        Contact.all.main.to_sql.should match(/contacts\.age >/)
      end
    end

    context "with argument" do
      it "is accessible from query object" do
        Contact.all.older(12).to_sql.should match(/contacts\.age >=/)
      end
    end

    context "same names" do
      it "is accessible from query object" do
        Address.all.main.to_sql.should match(/addresses\.main/)
        Contact.all.main.to_sql.should match(/contacts\.age >/)
      end
    end
  end

  describe "has_many macros" do
    it "adds relation name to RELATION_NAMES constant" do
      Contact::RELATION_NAMES.size.should eq(3)
      Contact::RELATION_NAMES[0].should eq("addresses")
    end

    context "query" do
      it "sets correct query part" do
        Contact.relation("addresses").condition_clause.to_sql.should eq("addresses.contact_id = contacts.id")
      end

      context "when desclaration has additional block" do
        it "sets correct query part" do
          Contact.relation("main_address").condition_clause.to_sql.should match(/addresses\.contact_id = contacts\.id AND addresses\.main/)
        end
      end
    end

    describe "relation_name_query" do
      it "returns query object" do
        c = contact_create
        q = c.addresses_query
        q.to_sql.should match(/addresses.contact_id = %s/)
        q.sql_args.should eq(db_array(c.id))
      end
    end

    describe "relation_name" do
      it "loads relation objects from db" do
        c = contact_create
        address_create(contact_id: c.id)
        c.addresses.should be_a(Array(Address))
        c.addresses.size.should eq(1)
      end
    end

    describe "set_relation_name" do
      it "builds new objects depending on given hash" do
        c = contact_build
        c.set_addresses({:main => true, :street => "some street", :contact_id => 1, :details => nil})
        c.addresses.size.should eq(1)
        c.addresses[0].street.should eq("some street")
      end
    end

    describe "relation_name_reload" do
      it "reloads objects" do
        c = contact_create
        a = address_create(contact_id: c.id)
        c.addresses
        a.street = "some strange street"
        a.save
        c.addresses_reload
        c.addresses[0].street.should eq("some strange street")
      end
    end
  end

  describe "belongs_to macros" do
    it "adds relation name to RELATION_NAMES constant" do
      Address::RELATION_NAMES.size.should eq(1)
      Address::RELATION_NAMES[0].should eq("contact")
    end

    context "query" do
      it "sets correct query part" do
        Address.relation("contact").condition_clause.to_sql.should eq("contacts.id = addresses.contact_id")
      end

      pending "when desclaration has additional block" do
        it "sets correct query part" do
          Address.relation("main_address").condition_clause.to_sql.should match(/addresses\.contact_id = contacts\.id AND addresses\.main/)
        end
      end
    end

    describe "relation_name_query" do
      it "returns query object" do
        a = address_create(contact_id: 1)
        q = a.contact_query
        q.to_sql.should match(/contacts.id = %s/)
        q.sql_args.should eq(db_array(a.contact_id))
      end
    end

    describe "relation_name" do
      it "loads relation objects from db" do
        c = contact_create
        a = address_create(contact_id: c.id)
        a.contact.should be_a(Contact?)
        a.contact.nil?.should be_false
      end
    end

    describe "set_relation_name" do
      it "builds new objects depending on given hash" do
        a = address_create
        a.set_contact({:name => "some name", :age => 16i16})
        a.contact!.name.should eq("some name")
      end
    end

    describe "relation_name_reload" do
      it "reloads objects" do
        c = contact_create
        a = address_create(contact_id: c.id)
        a.contact
        c.name = "some strange name"
        c.save
        a.contact_reload
        a.contact_reload.not_nil!.name.should eq("some strange name")
      end
    end
  end

  describe "has_one macros" do
    it "adds relation name to RELATION_NAMES constant" do
      Contact::RELATION_NAMES.size.should eq(3)
      Contact::RELATION_NAMES[0].should eq("addresses")
    end

    context "query" do
      it "sets correct query part" do
        Contact.relation("passport").condition_clause.to_sql.should eq("passports.contact_id = contacts.id")
      end

      context "when desclaration has additional block" do
        it "sets correct query part" do
          Contact.relation("main_address").condition_clause.to_sql.should match(/addresses\.contact_id = contacts\.id AND addresses\.main/)
        end
      end
    end

    describe "relation_name_query" do
      it "returns query object" do
        c = contact_create
        q = c.main_address_query
        q.to_sql.should match(/addresses.contact_id = %s AND addresses.main/)
        q.sql_args.should eq(db_array(c.id))
      end
    end

    describe "relation_name" do
      it "loads relation objects from db" do
        c = contact_create
        address_create(contact_id: c.id, main: true)
        c.main_address.nil?.should be_false
      end
    end

    describe "set_relation_name" do
      it "builds new objects depending on given hash" do
        c = contact_build
        c.set_main_address({:main => true, :street => "some street", :contact_id => 1, :details => nil})
        c.main_address.nil?.should be_false
      end
    end

    describe "relation_name_reload" do
      it "reloads objects" do
        c = contact_create
        a = address_create(contact_id: c.id, main: true)
        c.main_address
        a.street = "some strange street"
        a.save
        c.main_address_reload
        c.main_address!.street.should eq("some strange street")
      end
    end
  end

  describe "#set_relation" do
  end

  describe "::relations" do
  end

  describe "#destroy" do
  end

  describe "#delete" do
  end

  describe "::where" do
    it "returns query" do
      res = Contact.where { _id == 1 }
      res.should be_a(::Jennifer::QueryBuilder::Query(Contact))
    end
  end

  describe "::all" do
    it "returns empty query" do
      Contact.all.empty?.should be_true
    end
  end

  describe "::destroy" do
  end

  describe "::destroy_all" do
  end

  describe "::delete" do
  end

  describe "::delete_all" do
  end

  describe "::search_by_sql" do
    it "returns array" do
      contact_create(name: "Ivan", age: 15)
      contact_create(name: "Max", age: 19)
      contact_create(name: "Ivan", age: 50)

      res = Contact.search_by_sql("SELECT contacts.* from contacts where age > 16")

      res.size.should eq(2)
    end
  end
end
