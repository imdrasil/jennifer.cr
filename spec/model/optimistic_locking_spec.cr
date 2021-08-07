require "../spec_helper"

describe Jennifer::Model::OptimisticLocking do
  describe "#save" do
    it "increment lock version by one" do
      c1 = Factory.create_contact
      c1.lock_version.should eq(0)
      c1.age.should_not eq 55
      c1.age = 55
      c1.save
      c1.lock_version.should eq(1)
      c1.reload
      c1.age.should eq 55
      c1.lock_version.should eq(1)
    end

    it "raises stale object error" do
      c1 = Factory.create_contact
      c2 = Contact.find(c1.id).not_nil!
      c1.age = 55
      c1.save
      c2.name = "test name"
      expect_raises(Jennifer::StaleObjectError, /Optimistic locking failed due to stale object for model/) do
        c2.save
      end
      c2.lock_version.should eq 0
      c2.reload
      c2.age.should eq 55
      c2.lock_version.should eq 1
      c2.name.should_not eq "test name"
      c2.name = "test name"
      c2.save
      c2.lock_version.should eq 2
      c3 = Contact.find(c1.id).not_nil!
      c3.age.should eq 55
      c3.name.should eq "test name"
      c3.lock_version.should eq 2
    end
  end

  describe "#update_columns" do
    it "increment lock version by one" do
      c1 = Factory.create_contact
      c1.lock_version.should eq(0)
      c1.update_columns({:age => 55})
      c1.lock_version.should eq(1)
      c1.reload
      c1.lock_version.should eq(1)
    end

    it "raises stale object error" do
      c1 = Factory.create_contact
      c2 = Contact.find(c1.id).not_nil!
      c1.update_columns({:age => 55})
      expect_raises(Jennifer::StaleObjectError, /Optimistic locking failed due to stale object for model/) do
        c2.update_columns({:name => "test name"})
      end
      c2.age.should_not eq 55
      c2.lock_version.should eq 0
      c2.reload
      c2.age.should eq 55
      c2.lock_version.should eq 1
      c2.name.should_not eq "test name"
      c2.update_columns({:name => "test name"})
      c2.lock_version.should eq 2
      c3 = Contact.find(c1.id).not_nil!
      c3.age.should eq 55
      c3.name.should eq "test name"
      c3.lock_version.should eq 2
    end
  end
end
