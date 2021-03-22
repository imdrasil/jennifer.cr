require "../spec_helper"

describe Jennifer::Model::TimeZoneConverter do
  it "loads field from the database" do
    record = Factory.create_note.reload
    record.created_at!.zone.should eq(Jennifer::Config.local_time_zone.lookup(Time.utc))
    record.created_at!.should be_close(Time.local(location: Jennifer::Config.local_time_zone), 1.second)
  end

  it "is accepted by hash constructor" do
    record = Note.new({ "created_at" => Time.utc })
    record.created_at!.should be_close(Time.local(location: Jennifer::Config.local_time_zone), 1.second)
    record.created_at!.zone.should eq(Jennifer::Config.local_time_zone.lookup(Time.utc))
  end

  describe ".from_hash" do
    it "accepts time which is already in current time zone" do
      time = Time.local(location: Jennifer::Config.local_time_zone)
      value = Jennifer::Model::TimeZoneConverter.from_hash({ "value" => time }, "value", { name: "value" })
      value.should eq(time)
      value.zone.should eq(Jennifer::Config.local_time_zone.lookup(Time.utc))
    end
  end
end
