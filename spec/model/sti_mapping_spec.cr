require "../spec_helper"

describe Jennifer::Model::STIMapping do
  describe "#initialize" do
    context "ResultSet" do
      it "properly loads from db" do
        f = c = Factory.create_facebook_profile(uid: "111", login: "my_login")
        res = FacebookProfile.find!(f.id)
        res.uid.should eq("111")
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
      q.as_sql.should eq("profiles.type = %s")
      q.sql_args.should eq(db_array("FacebookProfile"))
    end
  end

  describe "#to_h" do
    it "sets all fields" do
      r = c = Factory.create_facebook_profile(uid: "111", login: "my_login").to_h
      r.has_key?(:id).should be_true
      r[:login].should eq("my_login")
      r[:type].should eq("FacebookProfile")
      r[:uid].should eq("111")
    end
  end

  describe "#to_str_h" do
    it "sets all fields" do
      r = Factory.build_facebook_profile(uid: "111", login: "my_login").to_str_h
      r["login"].should eq("my_login")
      r["type"].should eq("FacebookProfile")
      r["uid"].should eq("111")
    end
  end

  describe "#attribute" do
    it "returns attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
      f.attribute("uid").should eq("111")
    end

    it "returns parent attribute" do
      f = Factory.build_facebook_profile(uid: "111", login: "my_login")
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
