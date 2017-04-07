require "../spec_helper"

describe Jennifer::Model::Mapping do
  describe "mapping macro" do
    describe "::field_count" do
      it "returns correct number of model fields" do
        Contact.field_count.should eq(4)
      end
    end

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
  end

  describe "sti_mapping macro" do
    describe "#initialize" do
      context "ResultSet" do
        it "properly loads from db" do
          f = facebook_profile_create(uid: "111", login: "my_login")
          res = FacebookProfile.find!(f.id)
          res.uid.should eq("111")
          res.login.should eq("my_login")
        end
      end

      context "hash" do
        it "properly loads from hash" do
          f = FacebookProfile.new({:login => "asd", :uid => "uid"})
          f.type.should eq("FacebookProfile")
          f.login.should eq("asd")
          f.uid.should eq("uid")
        end
      end
    end

    describe "::field_names" do
      it "returns all fields" do
        names = FacebookProfile.field_names
        names.includes?("login").should be_true
        names.includes?("uid").should be_true
        names.includes?("type").should be_true
        names.includes?("contact_id").should be_true
        names.includes?("id").should be_true
        names.size.should eq(5)
      end
    end

    describe "#all" do
      it "generates correct query" do
        q = FacebookProfile.all
        q.to_sql.should eq("profiles.type = %s")
        q.sql_args.should eq(db_array("FacebookProfile"))
      end
    end

    describe "#to_h" do
      it "sets all fields" do
        r = facebook_profile_create(uid: "111", login: "my_login").to_h
        r.has_key?(:id).should be_true
        r[:login].should eq("my_login")
        r[:type].should eq("FacebookProfile")
        r[:uid].should eq("111")
      end
    end

    describe "#to_str_h" do
      it "sets all fields" do
        r = facebook_profile_build(uid: "111", login: "my_login").to_str_h
        r["login"].should eq("my_login")
        r["type"].should eq("FacebookProfile")
        r["uid"].should eq("111")
      end
    end

    describe "#attribute" do
      it "returns attribute" do
        f = facebook_profile_build(uid: "111", login: "my_login")
        f.attribute("uid").should eq("111")
      end

      it "returns parent attribute" do
        f = facebook_profile_build(uid: "111", login: "my_login")
        f.attribute("login").should eq("my_login")
      end
    end

    describe "#attributes_hash" do
      pending "returns all fields" do
      end
    end

    describe "#arguments_to_save" do
      pending "returns all arguments" do
      end
    end

    describe "#arguments_to_insert" do
      pending "returns all arguments" do
      end
    end
  end
end
