require "../spec_helper"

describe Jennifer::Model::TimeZoneConverter do
  described_class = Jennifer::Model::TimeZoneConverter

  it "converts column value to local time zone when is read from result set" do
    record = Factory.create_note.reload
    record.created_at!.zone.should eq(Jennifer::Config.local_time_zone.lookup(Time.utc))
    record.created_at!.should be_close(Time.local(location: Jennifer::Config.local_time_zone), 1.second)
  end

  it "converts column value to local time zone when is read from hash" do
    record = Note.new({"created_at" => Time.utc})
    record.created_at!.should be_close(Time.local(location: Jennifer::Config.local_time_zone), 1.second)
    record.created_at!.zone.should eq(Jennifer::Config.local_time_zone.lookup(Time.utc))
  end

  describe ".from_hash" do
    it "accepts time in current time zone" do
      time = Time.local(location: Jennifer::Config.local_time_zone)
      value = described_class.from_hash({"value" => time}, "value", {name: "value"})
      value.should eq(time)
      value.zone.should eq(Jennifer::Config.local_time_zone.lookup(Time.utc))
    end

    it "converts time to application time zone" do
      time = Time.utc
      value = described_class.from_hash({"value" => time}, "value", {name: "value"})
      value.should eq(time.in(Jennifer::Config.local_time_zone))
      value.zone.should eq(Jennifer::Config.local_time_zone.lookup(Time.utc))
    end

    it "assumes time in application time zone if time_zone_aware_attributes is off" do
      Jennifer::Config.time_zone_aware_attributes = false
      time = Time.utc
      value = described_class.from_hash({"value" => time}, "value", {name: "value"})
      value.should eq(time.to_local_in(Jennifer::Config.local_time_zone))
      value.zone.should eq(Jennifer::Config.local_time_zone.lookup(Time.utc))
    end

    it "assumes time in application time zone if time_zone_aware is specified" do
      time = Time.utc
      value = described_class.from_hash({"value" => time}, "value", {name: "value", time_zone_aware: false})
      value.should eq(time.to_local_in(Jennifer::Config.local_time_zone))
      value.zone.should eq(Jennifer::Config.local_time_zone.lookup(Time.utc))
    end

    it "accepts string value" do
      described_class.from_hash({"value" => "2010-12-10"}, "value", {name: "value"})
        .should eq(Time.local(2010, 12, 10, 0, 0, 0, location: ::Jennifer::Config.local_time_zone))
    end
  end

  describe ".coerce" do
    it "converts date-like string" do
      described_class.coerce("2010-12-10", {name: "value"})
        .should eq(Time.local(2010, 12, 10, 0, 0, 0, location: ::Jennifer::Config.local_time_zone))
    end

    it "uses specified custom date_format" do
      described_class.coerce("12/10/10", {name: "value", date_format: "%D"})
        .should eq(Time.local(2010, 12, 10, 0, 0, 0, location: ::Jennifer::Config.local_time_zone))
    end

    it "converts date-time-like string" do
      described_class.coerce("2010-12-10 20:10:10", {name: "value"})
        .should eq(Time.local(2010, 12, 10, 20, 10, 10, location: ::Jennifer::Config.local_time_zone))
    end

    it "uses specified custom date_time_format" do
      described_class.coerce("20:10:10 12/10/10", {name: "value", date_time_format: "%T %D"})
        .should eq(Time.local(2010, 12, 10, 20, 10, 10, location: ::Jennifer::Config.local_time_zone))
    end

    it "converts time-like string" do
      described_class.coerce("19:20", {name: "value"})
        .should eq(Time.local(1970, 1, 2, 19, 20, location: ::Jennifer::Config.local_time_zone))
    end

    it "uses specified custom time_format" do
      described_class.coerce("19:20:30", {name: "value", time_format: "%M:%H:%S"})
        .should eq(Time.local(1970, 1, 2, 20, 19, 30, location: ::Jennifer::Config.local_time_zone))
    end

    it "returns nil for an empty string" do
      described_class.coerce("", {name: "value"}).should be_nil
    end
  end
end
