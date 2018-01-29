require "../spec_helper"

describe Jennifer::Model::Localization do
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
  end
end