require "../spec_helper"

describe Jennifer::Model::Translation do
  describe "::human_attribute_name" do
    context "when attributes has localication" do
      it { Contact.human_attribute_name(:id).should eq("tId") }
    end

    context "when attributes have no localication" do
      it { Contact.human_attribute_name(:tags).should eq("Tags") }
      it { Contact.human_attribute_name(:created_at).should eq("Created at") }
    end

    context "when attributes defined by parent class" do
      it { FacebookProfile.human_attribute_name(:login).should eq("tLogin") }
      it { TwitterProfile.human_attribute_name(:login).should eq("phone") }
    end
  end

  describe "::human" do
    it { Contact.human.should eq("tContact") }
    it { FacebookProfile.human.should eq("Facebook profile") }
    it { Passport.human(1).should eq("Passport") }
    it { Passport.human(2).should eq("Many Passports") }
    it { Country.human(2).should eq("Countries") }
  end

  describe "::human_error" do
    context "without count" do
      klass = FacebookProfile
      
      it { klass.human_error(:uid, :child_error).should eq("uid child error") }
      it { klass.human_error(:id, :child_error).should eq("model child error") }
      it { klass.human_error(:id, :parent_error).should eq("id parent error") }
      it { klass.human_error(:uid, :parent_error).should eq("model parent error") }
      it { klass.human_error(:name, :global_error).should eq("name global error") }
      it { klass.human_error(:id, :global_error).should eq("global error") }
      it { klass.human_error(:id, :unknown_message).should eq("unknown message") }
    end
  end
end