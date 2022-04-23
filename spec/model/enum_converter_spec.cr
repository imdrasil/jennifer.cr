require "../spec_helper"

private enum Category
  GOOD
  BAD
end

class NoteWithEnumText < Jennifer::Model::Base
  table_name "notes"
  with_timestamps

  mapping({
    id:         Primary64,
    text:       {type: Category?, converter: Jennifer::Model::EnumConverter(Category)},
    created_at: Time?,
    updated_at: Time?,
  }, false)
end

describe Jennifer::Model::EnumConverter do
  it "loads field from the database" do
    id = Factory.create_note(text: "GOOD").id
    record = NoteWithEnumText.all.find!(id)
    record.text.should be_a(Category)
    record.text.should eq(Category::GOOD)
  end

  it "saves changed field to the database" do
    id = Factory.create_note(text: "GOOD").id
    record = NoteWithEnumText.all.find!(id)
    record.text = Category::BAD
    record.save
    record.reload.text.should eq(Category::BAD)
  end

  it "saves new record" do
    record = NoteWithEnumText.new({text: Category::GOOD})
    record.save
    record.reload.text.should eq(Category::GOOD)
  end

  it "is accepted by hash constructor" do
    record = NoteWithEnumText.new({"text" => Category::GOOD})
    record.text.should eq(Category::GOOD)
  end

  describe ".from_hash" do
    it "accepts string value" do
      Jennifer::Model::EnumConverter(Category).from_hash({"value" => "GOOD"}, "value", {name: "value"}).should eq(Category::GOOD)
    end
  end
end
