require "../spec_helper"

describe Jennifer::Model::Base do
  describe "#changed?" do
    it "returns true if at list one field was changed" do
      c = Factory.build_contact
      c.name = "new name"
      c.changed?.should be_true
    end

    it "returns false if no one field was changed" do
      Factory.build_contact.changed?.should be_false
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
      c = Factory.build_contact
      c.init_primary_field(1)
      c.primary.should eq(1)
    end

    it "raises error if it is set" do
      c = Factory.build_contact
      c.init_primary_field(1)
      expect_raises(Exception, "Primary field is already initialized") do
        c.init_primary_field(1)
      end
    end
  end

  describe "#new_record?" do
    it "returns true if mrimary field nil" do
      Factory.build_contact.new_record?.should be_true
    end

    it "returns false if primary field is not nil" do
      Factory.create_contact.new_record?.should be_false
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
        c = Factory.create_contact
        c.name = "new name"
        c.save
        Contact.find!(c.id).name.should eq("new name")
      end

      it "returns true if record was saved" do
        c = Factory.create_contact
        c.id.nil?.should be_false
        c.name = "new name"
        c.save.should be_true
      end

      it "returns false if record wasn't saved" do
        Factory.create_contact.save.should be_false
      end

      it "calls after_save_callback" do
        c = Factory.create_contact
        c.name = "new name"
        c.save
        c.name_changed?.should be_false
      end
    end

    context "brakes unique index" do
      it "raises exception" do
        void_transaction do
          Factory.create_address(street: "st. 1")
          expect_raises(Jennifer::BaseException) do
            Factory.create_address(street: "st. 1")
          end
        end
      end
    end
  end

  describe "::table_name" do
  end

  describe "::c" do
  end

  describe "%scope" do
    context "with block" do
      it "executes in query context" do
        ::Jennifer::Adapter::SqlGenerator.select(Contact.all.ordered).should match(/ORDER BY name ASC/)
      end

      context "without arguemnt" do
        it "is accessible from query object" do
          Contact.all.main.as_sql.should match(/contacts\.age >/)
        end
      end

      context "with argument" do
        it "is accessible from query object" do
          Contact.all.older(12).as_sql.should match(/contacts\.age >=/)
        end
      end

      context "same names" do
        it "is accessible from query object" do
          Address.all.main.as_sql.should match(/addresses\.main/)
          Contact.all.main.as_sql.should match(/contacts\.age >/)
        end
      end

      it "is chainable" do
        c1 = Factory.create_contact(age: 15)
        c2 = Factory.create_contact(age: 15)
        c3 = Factory.create_contact(age: 13)
        Factory.create_address(contact_id: c1.id, main: true)
        Factory.create_address(contact_id: c2.id, main: false)
        Factory.create_address(contact_id: c3.id, main: true)
        Contact.all.with_main_address.older(14).count.should eq(1)
      end
    end

    context "with query object class" do
      it "executes in class context" do
        ::Jennifer::Adapter::SqlGenerator.select(Contact.johny).should match(/name =/)
      end

      context "without arguemnt" do
        it "is accessible from query object" do
          Contact.all.johny.as_sql.should match(/contacts\.name =/)
        end
      end

      context "with argument" do
        it "is accessible from query object" do
          Contact.all.by_age(12).as_sql.should match(/contacts\.age =/)
        end
      end

      it "is chainable" do
        c1 = Factory.create_contact(name: "Johny")
        c3 = Factory.create_contact
        Factory.create_address(contact_id: c1.id, main: true)
        Factory.create_address(contact_id: c3.id, main: true)
        Contact.all.with_main_address.johny.count.should eq(1)
      end
    end
  end

  describe "#set_relation" do
    pending "add" do
    end
  end

  describe "::relations" do
    pending "add" do
    end
  end

  describe "#destroy" do
    pending "add" do
    end
  end

  describe "#delete" do
    pending "add" do
    end
  end

  describe "#lock!" do
    it "lock current record" do
      Factory.create_contact.lock!
    end

    # TODO: find how to test this - now everything is a transaction in test env
    pending "raises exception if transaction is not started" do
    end
  end

  describe "#with_lock" do
    # TODO: find how to properly test this one
    it "starts transaction" do
      expect_raises(DivisionByZero) do
        Factory.create_contact.with_lock do
          Factory.create_contact
          1 / 0
        end
      end
      Contact.all.count.should eq(1)
    end
  end

  describe "::transaction" do
    it "allow to start transaction" do
      expect_raises(DivisionByZero) do
        Contact.transaction do
          Factory.create_contact
          1 / 0
        end
      end
      Contact.all.count.should eq(0)
    end
  end

  describe "::where" do
    it "returns query" do
      res = Contact.where { _id == 1 }
      res.should be_a(::Jennifer::QueryBuilder::ModelQuery(Contact))
    end
  end

  describe "::all" do
    it "returns empty query" do
      Contact.all.empty?.should be_true
    end
  end

  describe "::destroy" do
    it "deletes from db by given ids" do
      c = [] of Int32?
      3.times { |i| c << Factory.create_contact.id }
      Contact.destroy(c[0..1])
      Contact.all.count.should eq(1)
    end
  end

  describe "::delete" do
    it "deletes from db by given ids" do
      c = [] of Int32?
      3.times { |i| c << Factory.create_contact.id }
      Contact.delete(c[0..1])
      Contact.all.count.should eq(1)
    end
  end

  describe "::search_by_sql" do
    it "returns array" do
      Factory.create_contact(name: "Ivan", age: 15)
      Factory.create_contact(name: "Max", age: 19)
      Factory.create_contact(name: "Ivan", age: 50)

      res = Contact.search_by_sql("SELECT contacts.* from contacts where age > 16")

      res.size.should eq(2)
    end
  end

  describe "::models" do
    it "returns all model classes" do
      models = Jennifer::Model::Base.models
      models.is_a?(Array(Jennifer::Model::Base.class)).should be_true
      # I tired from modifing this each time new model is added
      (models.size > 6).should be_true
    end
  end
end
