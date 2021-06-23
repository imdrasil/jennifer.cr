require "../spec_helper"

describe Jennifer::Model::JSONConverter do
  it "loads field from the database" do
    id = Factory.create_address(details: {latitude: 32.0, longitude: 24.5}.to_json).id
    record = Address.all.find!(id)
    record.details.should be_a(JSON::Any)
    record.details!["latitude"].should eq(32.0)
    record.details!["longitude"].should eq(24.5)
  end

  it "saves changed field to the database" do
    record = Factory.create_address(details: {latitude: 32.0, longitude: 24.5}.to_json)
    record.details!.as_h["latitude"] = JSON::Any.new(1i64)
    record.details_will_change!
    record.save
    record.reload.details!["latitude"].should eq(1.0)
  end

  it "saves new record" do
    record = Address.create({
      main:    false,
      street:  "street",
      details: JSON::Any.new({"latitude" => JSON::Any.new(32.0)}),
    })
    record.reload.details!["latitude"].should eq(32.0)
  end

  it "is accepted by hash constructor" do
    record = Address.new({
      "main"    => false,
      "street"  => "street",
      "details" => JSON::Any.new({"latitude" => JSON::Any.new(32.0)}),
    })
    record.details!["latitude"].should eq(32.0)
  end

  describe ".from_hash" do
    it "accepts string value" do
      data = {latitude: 32.0, longitude: 24.5}
      Jennifer::Model::JSONConverter.from_hash({"value" => data.to_json}, "value", {name: "value"})
        .should eq(JSON.parse(data.to_json))
    end
  end
end
