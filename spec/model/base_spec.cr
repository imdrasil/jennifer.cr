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
      c = Contact.where { name == "a" }.tree.as(Jennifer::QueryBuilder::Criteria)
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

    pending "updates existing object in db" do
    end
  end

  describe "#attribute" do
    it "returns attribute value by given name" do
      c = contact_build(name: "Jessy")
      c.attribute("name").should eq("Jessy")
      c.attribute(:name).should eq("Jessy")
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
  end

  describe "has_many macros" do
  end

  describe "belongs_to macros" do
  end

  describe "has_one macros" do
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
  end

  describe "::all" do
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
  end
end
