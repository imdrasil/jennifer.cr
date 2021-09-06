require "../spec_helper"

class Spec::TestClassForTranslation
  include Jennifer::Model::Translation

  def self.superclass; end
end

describe Jennifer::Model::Translation do
  test_class_instance = Spec::TestClassForTranslation.new

  describe ".human_attribute_name" do
    context "when attributes has localization" do
      it { Contact.human_attribute_name(:id).should eq("tId") }
    end

    context "when attributes have no localization" do
      it { Contact.human_attribute_name(:tags).should eq("Tags") }
      it { Contact.human_attribute_name(:created_at).should eq("Created at") }
    end

    context "when attributes defined by parent class" do
      it { FacebookProfile.human_attribute_name(:login).should eq("tLogin") }
      it { TwitterProfile.human_attribute_name(:login).should eq("phone") }
    end
  end

  describe ".human" do
    it { Contact.human.should eq("tContact") }
    it { FacebookProfile.human.should eq("Facebook profile") }
    it { Passport.human(1).should eq("Passport") }
    it { Passport.human(2).should eq("Many Passports") }
    it { Country.human(2).should eq("Countries") }
  end

  describe ".i18n_scope" do
    it { Contact.i18n_scope.should eq(:models) }
  end

  describe ".i18n_key" do
    it { Contact.i18n_key.should eq("contact") }
    it { FacebookProfile.i18n_key.should eq("facebook_profile") }
    it { Spec::TestClassForTranslation.i18n_key.should eq("test_class_for_translation") }
  end

  describe ".lookup_ancestors" do
    it do
      index = 0
      FacebookProfile.lookup_ancestors do |klass|
        klass.should eq(
          case index
          when 0
            FacebookProfile
          when 1
            Profile
          when 2
            ApplicationRecord
          when 3
            Jennifer::Model::Base
          else
            fail "Invalid lookup ancestor class: #{klass}"
          end
        )
        index += 1
      end
      index.should eq(4)
    end

    describe "non-model class" do
      it do
        executed = false
        Spec::TestClassForTranslation.lookup_ancestors do |klass|
          klass.should eq(Spec::TestClassForTranslation)
          executed = true
        end
        executed.should be_true
      end
    end
  end

  describe "#lookup_ancestors" do
    it do
      index = 0
      Factory.build_facebook_profile.lookup_ancestors do |klass|
        klass.should eq(
          case index
          when 0
            FacebookProfile
          when 1
            Profile
          when 2
            ApplicationRecord
          when 3
            Jennifer::Model::Base
          else
            fail "Invalid lookup ancestor class: #{klass}"
          end
        )
        index += 1
      end
      index.should eq(4)
    end

    describe "non-model class" do
      it do
        executed = false
        test_class_instance.lookup_ancestors do |klass|
          klass.should eq(Spec::TestClassForTranslation)
          executed = true
        end
        executed.should be_true
      end
    end
  end

  describe "#human_attribute_name" do
    context "when attributes has localization" do
      it { Factory.build_contact.human_attribute_name(:id).should eq("tId") }
    end

    context "when attributes have no localization" do
      it { Factory.build_contact.human_attribute_name(:tags).should eq("Tags") }
      it { Factory.build_contact.human_attribute_name(:created_at).should eq("Created at") }
    end

    context "when attributes defined by parent class" do
      it { Factory.build_facebook_profile.human_attribute_name(:login).should eq("tLogin") }
      it { Factory.build_twitter_profile.human_attribute_name(:login).should eq("phone") }
    end

    describe "non-model class" do
      context "when attributes have no localization" do
        it { test_class_instance.human_attribute_name(:tags).should eq("Tags") }
        it { test_class_instance.human_attribute_name(:created_at).should eq("Created at") }
      end
    end
  end

  describe "#class_name" do
    it { Factory.build_contact.class_name.should eq("contact") }
    it { Jennifer::Migration::Version.new({version: "1"}).class_name.should eq("jennifer_migration_version") }
  end
end
