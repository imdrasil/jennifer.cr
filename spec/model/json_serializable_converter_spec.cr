require "../spec_helper"

private class Location
  include JSON::Serializable

  property latitude : Float64
  property longitude : Float64

  def initialize(@latitude, @longitude)
  end

  def ==(other)
    latitude == other.latitude && longitude == other.longitude
  end
end

class AddressWithSerializable < Jennifer::Model::Base
  table_name "addresses"
  with_timestamps

  mapping({
    id:         Primary64,
    details:    {type: Location?, converter: Jennifer::Model::JSONSerializableConverter(Location)},
    created_at: Time?,
    updated_at: Time?,
  }, false)
end

describe Jennifer::Model::JSONSerializableConverter do
  it "loads field from the database" do
    id = Factory.create_address(details: {latitude: 32.0, longitude: 24.5}.to_json).id
    record = AddressWithSerializable.all.find!(id)
    record.details.should be_a(Location)
    record.details!.latitude.should eq(32.0)
    record.details!.longitude.should eq(24.5)
  end

  it "saves changed field to the database" do
    id = Factory.create_address(details: {latitude: 32.0, longitude: 24.5}.to_json).id
    record = AddressWithSerializable.all.find!(id)
    record.details!.latitude = 1
    record.details_will_change!
    record.save
    record.reload.details!.latitude.should eq(1.0)
  end

  it "saves new record" do
    location = Location.new(22.0, 30.0)
    record = AddressWithSerializable.new({details: location})
    record.save
    record.reload.details!.latitude.should eq(22.0)
  end

  it "is accepted by hash constructor" do
    location = Location.new(22.0, 30.0)
    record = AddressWithSerializable.new({"details" => location})
    record.details!.latitude.should eq(22.0)
  end

  describe ".from_hash" do
    it "accepts string value" do
      data = {latitude: 32.0, longitude: 24.5}
      Jennifer::Model::JSONSerializableConverter(Location).from_hash({"value" => data.to_json}, "value", {name: "value"})
        .should eq(Location.new(32.0, 24.5))
    end

    it "accepts JSON::Any value" do
      data = {latitude: 32.0, longitude: 24.5}
      Jennifer::Model::JSONSerializableConverter(Location).from_hash({"value" => JSON.parse(data.to_json)}, "value", {name: "value"})
        .should eq(Location.new(32.0, 24.5))
    end
  end
end
