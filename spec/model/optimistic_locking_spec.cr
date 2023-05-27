require "../spec_helper"

describe Jennifer::Model::OptimisticLocking do
  describe "#save" do
    it "increment lock version by one" do
      c1 = Factory.create_city(name: "Old")
      c1.update({:name => "New"})
      c1.lock_version.should eq(1)
      c1.reload
      c1.name.should eq("New")
      c1.lock_version.should eq(1)
    end

    it "does not reset lock version when it's not changed" do
      c1 = Factory.create_city(name: "Old")
      c1.lock_version.should eq(0)
      expect_raises(Exception, /name can't be blank/) do
        c1.update!({:name => ""})
      end
      c1.lock_version.should eq(0)
    end

    it "raises stale object error" do
      c1 = Factory.create_city(name: "Old")
      c2 = City.find!(c1.id)
      c1.update({:name => "New"})
      expect_raises(Jennifer::StaleObjectError, /Optimistic locking failed due to stale object for model/) do
        c2.update({:name => "Test"})
      end
      c2.lock_version.should eq(0)
      c2.reload
      c2.name.should eq("New")
      c2.lock_version.should eq(1)

      c2.update({:name => "Test"})
      c2.reload
      c2.name.should eq("Test")
      c2.lock_version.should eq(2)
    end
  end

  describe "#update_columns" do
    it "doesn't increment lock version" do
      c1 = Factory.create_city(name: "Old")
      c1.lock_version.should eq(0)
      c1.update_columns({:name => "New"})
      c1.lock_version.should eq(0)
      c1.reload
      c1.lock_version.should eq(0)
    end
  end

  describe "#destroy" do
    it "raises stale object error" do
      c1 = Factory.create_city(name: "Old")
      c2 = City.find!(c1.id)
      c1.update({:name => "New"})
      expect_raises(Jennifer::StaleObjectError, /Optimistic locking failed due to stale object for model/) do
        c2.destroy
      end
    end
  end

  describe "#delete" do
    it "doesn't raise stale object error" do
      c1 = Factory.create_city(name: "Old")
      c2 = City.find!(c1.id)
      c1.update({:name => "New"})
      c2.delete
    end
  end
end
