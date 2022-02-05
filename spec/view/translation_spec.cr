require "../spec_helper"

# View and materialized view localization
describe Jennifer::Model::Translation do
  describe "View" do
    describe ".human_attribute_name" do
      context "when attributes has localication" do
        it { MaleContact.human_attribute_name(:id).should eq("tId") }
      end

      context "when attributes have no localication" do
        it { MaleContact.human_attribute_name(:age).should eq("Age") }
        it { MaleContact.human_attribute_name(:created_at).should eq("Created at") }
      end

      pending "when attributes defined by parent class" do
      end
    end

    describe ".human" do
      it { MaleContact.human.should eq("tMale contact") }
      it { FakeContactView.human.should eq("Fake contact view") }
    end
  end

  describe "Materialized view" do
    describe ".human_attribute_name" do
      context "when attributes has localization" do
        it { FemaleContact.human_attribute_name(:id).should eq("tId") }
      end

      context "when attributes have no localization" do
        it { FemaleContact.human_attribute_name(:age).should eq("Age") }
        it { FemaleContact.human_attribute_name(:created_at).should eq("Created at") }
      end

      pending "when attributes defined by parent class" do
      end
    end

    describe ".human" do
      it { FemaleContact.human.should eq("tFemale contact") }
      it { FakeFemaleContact.human.should eq("Fake female contact") }
    end
  end
end
