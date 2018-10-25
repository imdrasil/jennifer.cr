require "../spec_helper"

describe Jennifer::Model::STIMapping do
  describe "%sti_mapping" do
    context "columns metadata" do
      it "sets constant" do
        FacebookProfile::COLUMNS_METADATA.is_a?(NamedTuple).should be_true
      end

      it "copies data from superclass" do
        id = FacebookProfile::COLUMNS_METADATA[:id]
        id.is_a?(NamedTuple).should be_true
        id[:type].should eq(Int32)
        id[:parsed_type].should eq("Int32?")
      end
    end

    describe "::columns_tuple" do
      it "returns named tuple mith column metedata" do
        metadata = FacebookProfile.columns_tuple
        metadata.is_a?(NamedTuple).should be_true
        metadata[:uid].is_a?(NamedTuple).should be_true
        metadata[:uid][:type].should eq(String?)
        metadata[:uid][:parsed_type].should eq("::Union(String, ::Nil)")
      end
    end

    context "types" do
      context "nillable" do
        context "using ? without named tuple" do
          it "parses type as nillable" do
            typeof(Factory.build_facebook_profile.uid).should eq(String?)
          end
        end

        context "using :null option" do
          it "parses type as nillable" do
            typeof(Factory.build_twitter_profile.email).should eq(String?)
          end
        end
      end
    end

    pending "defines default constructor if all fields are nillable or have default values and superclass has default constructor" do
      TwitterProfile::WITH_DEFAULT_CONSTRUCTOR.should be_true
    end

    it "doesn't define default constructor if all fields are nillable or have default values" do
      TwitterProfile::WITH_DEFAULT_CONSTRUCTOR.should be_false
    end
  end

  describe "#initialize" do
    context "ResultSet" do
      it "properly loads from db" do
        f = c = Factory.create_facebook_profile(uid: "1111", login: "my_login")
        res = FacebookProfile.find!(f.id)
        res.uid.should eq("1111")
        res.login.should eq("my_login")
      end
    end

    context "hash" do
      it "properly loads from hash" do
        f = FacebookProfile.build({:login => "asd", :uid => "uid"})
        f.type.should eq("FacebookProfile")
        f.login.should eq("asd")
        f.uid.should eq("uid")
      end
    end
  end

  describe "::field_names" do
    it "returns all fields" do
      names = FacebookProfile.field_names
      match_array(names, %w(login uid type contact_id id virtual_child_field virtual_parent_field))
    end
  end

  describe "::all" do
    it "generates correct query" do
      q = FacebookProfile.all
      q.as_sql.should eq("profiles.type = %s")
      q.sql_args.should eq(db_array("FacebookProfile"))
    end
  end

  describe "#to_h" do
    it "sets all fields" do
      r = c = Factory.build_facebook_profile(uid: "1111", login: "my_login").to_h
      r.keys.should eq(%i(id login contact_id type uid))
      r[:login].should eq("my_login")
      r[:type].should eq("FacebookProfile")
      r[:uid].should eq("1111")
    end
  end

  describe "#to_str_h" do
    it "sets all fields" do
      r = Factory.build_facebook_profile(uid: "1111", login: "my_login").to_str_h
      r.keys.should eq(%w(id login contact_id type uid))
      r["login"].should eq("my_login")
      r["type"].should eq("FacebookProfile")
      r["uid"].should eq("1111")
    end
  end

  describe "#update_column" do
    it "properly updates given attribute" do
      p = Factory.create_facebook_profile(uid: "1111")
      p.update_column(:uid, "2222")
      p.uid.should eq("2222")
      p.reload.uid.should eq("2222")
    end
  end

  describe "#update_columns" do
    context "updating attributes described in child model" do
      it "properly updates them" do
        p = Factory.create_facebook_profile(uid: "1111")
        p.update_columns({:uid => "2222"})
        p.uid.should eq("2222")
        p.reload.uid.should eq("2222")
      end
    end

    context "updating attributes described in parent model" do
      it "properly updates them" do
        p = Factory.create_facebook_profile(login: "111")
        p.update_columns({:login => "222"})
        p.login.should eq("222")
        p.reload.login.should eq("222")
      end
    end

    context "updating own and inherited attributes" do
      it "properly updates them" do
        p = Factory.create_facebook_profile(login: "111", uid: "2222")
        p.update_columns({:login => "222", :uid => "3333"})
        p.login.should eq("222")
        p.uid.should eq("3333")
        p.reload
        p.login.should eq("222")
        p.uid.should eq("3333")
      end
    end

    it "raises exception if any given attribute is not exists" do
      p = Factory.create_facebook_profile(login: "111")
      expect_raises(Jennifer::BaseException) do
        p.update_columns({:asd => "222"})
      end
    end
  end

  describe "#attribute" do
    it "returns virtual attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.virtual_child_field = 2
      f.attribute(:virtual_child_field).should eq(2)
    end

    it "returns own attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.attribute("uid").should eq("111")
    end

    it "returns parent attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.attribute("login").should eq("my_login")
    end
  end

  describe "#arguments_to_save" do
    it "returns named tuple with correct keys" do
      r = Factory.build_twitter_profile.arguments_to_save
      r.is_a?(NamedTuple).should be_true
      r.keys.should eq({:args, :fields})
    end

    it "returns tuple with empty arguments if no field was changed" do
      r = Factory.build_twitter_profile.arguments_to_save
      r[:args].empty?.should be_true
      r[:fields].empty?.should be_true
    end

    it "returns tuple with changed parent argument" do
      c = Factory.build_twitter_profile
      c.login = "some new login"
      r = c.arguments_to_save
      r[:args].should eq(db_array("some new login"))
      r[:fields].should eq(db_array("login"))
    end

    it "returns tuple with changed own argument" do
      c = Factory.build_twitter_profile
      c.email = "some new email"
      r = c.arguments_to_save
      r[:args].should eq(db_array("some new email"))
      r[:fields].should eq(db_array("email"))
    end
  end

  describe "#arguments_to_insert" do
    it "returns named tuple with :args and :fields keys" do
      r = Factory.build_twitter_profile.arguments_to_insert
      r.is_a?(NamedTuple).should be_true
      r.keys.should eq({:args, :fields})
    end

    it "returns tuple with all fields" do
      r = Factory.build_twitter_profile.arguments_to_insert
      match_array(r[:fields], %w(login contact_id type email))
    end

    it "returns tuple with all values" do
      r = Factory.build_twitter_profile.arguments_to_insert
      match_array(r[:args], db_array("some_login", nil, "TwitterProfile", "some_email@example.com"))
    end
  end

  describe "#reload" do
    it "properly reloads fields" do
      p = Factory.create_facebook_profile(uid: "1111")
      p1 = FacebookProfile.all.last!
      p1.uid = "2222"
      p1.save!
      p.reload.uid.should eq("2222")
    end
  end
end
