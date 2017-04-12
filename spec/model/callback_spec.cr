require "../spec_helper"

# TODO: just dummy test to be sure everything are work; rewrite to better test of proper call moment
describe Jennifer::Model::Callback do
  describe "before_save" do
    it "is called before any save" do
      c = country_build
      c.before_save_attr.should be_false
      c.save
      c.before_save_attr.should be_true
    end
  end

  describe "after_save" do
    it "is called after any save" do
      c = country_build
      c.after_save_attr.should be_false
      c.save
      c.after_save_attr.should be_true
    end
  end

  describe "before_create" do
    it "is called before create" do
      c = country_build
      c.before_create_attr.should be_false
      c.save
      c.before_create_attr.should be_true
    end

    it "is not called before update" do
      country_create
      c = Country.all.first!
      c.name = "k2"
      c.before_create_attr.should be_false
      c.save
      c.before_create_attr.should be_false
    end
  end

  describe "after_create" do
    it "is called after create" do
      c = country_build
      c.after_create_attr.should be_false
      c.save
      c.after_create_attr.should be_true
    end

    it "is not called after update" do
      country_create
      c = Country.all.first!
      c.name = "k2"
      c.after_create_attr.should be_false
      c.save
      c.after_create_attr.should be_false
    end
  end

  describe "after_initialize" do
    it "is called after build" do
      c = country_build
      c.after_initialize_attr.should be_true
    end

    it "is called after loading from db" do
      country_create
      c = Country.all.first!
      c.after_initialize_attr.should be_true
    end
  end

  describe "before_destroy" do
    it "is called before destroy" do
      c = country_create
      c.destroy
      c.before_destroy_attr.should be_true
    end

    it "is not called before delete" do
      c = country_create
      c.delete
      c.before_destroy_attr.should be_false
    end
  end
end
