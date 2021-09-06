require "../spec_helper"

describe Jennifer::Model::Timestamp do
  it "sets both created_at and updated_at on create" do
    c = Factory.build_contact
    c.created_at.should be_nil
    c.updated_at.should be_nil
    c.save!
    c.updated_at.should eq(c.created_at)
    c.updated_at.should_not be_nil
  end

  it "changes updated_at on update" do
    c = Factory.create_contact
    c.updated_at.should eq(c.created_at)
    sleep(0.1)
    c.name = "new name"
    c.save!
    (c.updated_at! > c.created_at!).should be_true
  end

  it "doesn't trigger update if nothing changed" do
    c = Factory.create_contact
    c.updated_at.should eq(c.created_at)
    sleep(0.1)
    c.save!
    c.updated_at.should eq(c.created_at)
  end

  pending "when created_at is disabled"
  pending "when updated_at is disabled"
end
