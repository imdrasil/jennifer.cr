require "../spec_helper"

describe Jennifer::Generators::FieldSet do
  described_class = Jennifer::Generators::FieldSet
  field_class = Jennifer::Generators::Field

  describe ".new" do
    context "without id definition" do
      it do
        described_class.new(%w(name:string)).id.should eq(field_class.new("id", "bigint", true))
      end
    end
  end

  describe "#references" do
    it do
      described_class.new(%w(name:string author:reference)).references.should eq([field_class.new("author", "reference", true)])
    end
  end

  describe "#common_fields" do
    it do
      described_class.new(%w(name:string author:reference)).common_fields.should eq([field_class.new("name", "string", false)])
    end
  end

  describe "#timestamps" do
    it do
      described_class.new(%w(name:string author:reference)).timestamps.should eq([field_class.new("created_at", "timestamp", true), field_class.new("updated_at", "timestamp", true)])
    end
  end
end
