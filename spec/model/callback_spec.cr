require "../spec_helper"

# TODO: just dummy test to be sure everything are work; rewrite to better test of proper call moment
describe Jennifer::Model::Callback do
  describe "before_save" do
    it "is called before any save" do
      c = Factory.build_country
      c.before_save_attr.should be_false
      c.save
      c.before_save_attr.should be_true
    end
  end

  describe "after_save" do
    it "is called after any save" do
      c = Factory.build_country
      c.after_save_attr.should be_false
      c.save
      c.after_save_attr.should be_true
    end
  end

  describe "before_create" do
    it "is called before create" do
      c = Factory.build_country
      c.before_create_attr.should be_false
      c.save
      c.before_create_attr.should be_true
    end

    it "is not called before update" do
      Factory.create_country
      c = Country.all.first!
      c.name = "k2"
      c.before_create_attr.should be_false
      c.save
      c.before_create_attr.should be_false
    end

    it "not stops creating if before callback raises Skip exceptions" do
      c = Factory.create_country(name: "not create")
      c.new_record?.should be_true
    end
  end

  describe "after_create" do
    it "is called after create" do
      c = Factory.build_country
      c.after_create_attr.should be_false
      c.save
      c.after_create_attr.should be_true
    end

    it "is not called after update" do
      Factory.create_country
      c = Country.all.first!
      c.name = "k2"
      c.after_create_attr.should be_false
      c.save
      c.after_create_attr.should be_false
    end
  end

  describe "after_initialize" do
    it "is called after build" do
      c = CountryFactory.build
      c.after_initialize_attr.should be_true
    end

    it "is called after loading from db" do
      Factory.create_country
      c = Country.all.first!
      c.after_initialize_attr.should be_true
    end
  end

  describe "before_destroy" do
    it "is called before destroy" do
      c = Factory.create_country
      c.destroy
      c.before_destroy_attr.should be_true
    end

    it "is not called before delete" do
      c = Factory.create_country
      c.delete
      c.before_destroy_attr.should be_false
    end
  end

  describe "after_destroy" do
    it "is called after destroy" do
      c = Factory.create_country
      c.destroy
      c.after_destroy_attr.should be_true
    end

    it "is not called if before destroy callback adds error" do
      c = Factory.create_country(name: "not kill")
      c.destroy
      c.destroyed?.should be_false
      c.after_destroy_attr.should be_false
      Country.all.count.should eq(1)
    end
  end
end
