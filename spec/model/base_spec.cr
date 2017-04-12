require "../spec_helper"

describe Jennifer::Model::Base do
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

  describe "::table_name" do
  end

  describe "::c" do
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
    pending "add" do
    end
  end

  describe "::destroy_all" do
    pending "add" do
    end
  end

  describe "::delete" do
    pending "add" do
    end
  end

  describe "::delete_all" do
    pending "add" do
    end
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
