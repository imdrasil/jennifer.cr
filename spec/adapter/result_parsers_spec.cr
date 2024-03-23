require "../spec_helper"

describe Jennifer::Adapter::ResultParsers do
  adapter = Jennifer::Adapter.default_adapter

  describe "#result_to_hash" do
    describe "data types" do
      describe "BOOLEAN" do
        it do
          AllTypeModel.create(bool_f: false)
          executed = false
          AllTypeModel.all.each_result_set do |rs|
            executed = true
            value = adapter.result_to_hash(rs)["bool_f"]
            value.is_a?(Bool).should be_true
            value.should be_false
          end
          executed.should be_true
        end
      end

      describe "TIMESTAMP" do
        it "correctly saves and loads" do
          AllTypeModel.create!(timestamp_f: Time.utc(2016, 2, 15, 10, 20, 30))
          executed = false
          AllTypeModel.all.each_result_set do |rs|
            executed = true
            value = adapter.result_to_hash(rs)["timestamp_f"]
            value.is_a?(Time).should be_true
          end
          executed.should be_true
        end
      end

      describe "DATE" do
        it "correctly saves and loads" do
          AllTypeModel.create!({:date_f => Time.utc(2016, 2, 15, 10, 20, 30)})
          executed = false
          AllTypeModel.all.each_result_set do |rs|
            executed = true
            value = adapter.result_to_hash(rs)["date_f"]
            value.is_a?(Time).should be_true
            value.as(Time).in(UTC).should eq(Time.utc(2016, 2, 15, 0, 0, 0))
          end
          executed.should be_true
        end
      end

      describe "JSON" do
        it "correctly loads json field" do
          AllTypeModel.create!(json_f: {:a => 2}.to_json)
          executed = false
          AllTypeModel.all.each_result_set do |rs|
            executed = true
            value = adapter.result_to_hash(rs)["json_f"]
            db_specific(
              mysql: ->do
                value.is_a?(JSON::Any).should be_true
                value.should eq(JSON.parse(%({"a": 2})))
              end,
              postgres: ->do
                value.is_a?(JSON::PullParser).should be_true
                JSON::Any.new(value.as(JSON::PullParser)).should eq(JSON.parse(%({"a": 2})))
              end
            )
          end
          executed.should be_true
        end
      end

      mysql_only do
        describe "TINYINT" do
          it do
            AllTypeModel.create(tinyint_f: 1i8)
            executed = false
            AllTypeModel.all.each_result_set do |rs|
              executed = true
              value = adapter.result_to_hash(rs)["tinyint_f"]
              value.is_a?(Int8).should be_true
              value.should eq(1i8)
            end
            executed.should be_true
          end
        end
      end

      postgres_only do
        describe "DECIMAL" do
          it "correctly saves and loads" do
            AllTypeModel.create!(decimal_f: PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [1i16]))
            executed = false
            AllTypeModel.all.each_result_set do |rs|
              executed = true
              value = adapter.result_to_hash(rs)["decimal_f"]
              value.is_a?(PG::Numeric).should be_true
              value.should eq(PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [1i16]))
            end
            executed.should be_true
          end
        end

        describe "OID" do
          it "correctly saves and loads" do
            AllTypeModel.create!(oid_f: 2147483648_u32)
            executed = false
            AllTypeModel.all.each_result_set do |rs|
              executed = true
              value = adapter.result_to_hash(rs)["oid_f"]
              value.is_a?(UInt32).should be_true
              value.should eq(2147483648_u32)
            end
            executed.should be_true
          end
        end

        describe "CHAR" do
          it "correctly saves and loads" do
            AllTypeModel.create!(char_f: "a")
            executed = false
            AllTypeModel.all.each_result_set do |rs|
              executed = true
              value = adapter.result_to_hash(rs)["char_f"]
              value.is_a?(String).should be_true
              value.should eq("a")
            end
            executed.should be_true
          end
        end

        describe "UUID" do
          it "correctly saves and loads" do
            uuid = UUID.new("7d61d548-124c-4b38-bc05-cfbb88cfd1d1")
            AllTypeModel.create!(uuid_f: uuid)
            executed = false
            AllTypeModel.all.each_result_set do |rs|
              executed = true
              value = adapter.result_to_hash(rs)["uuid_f"]
              value.is_a?(UUID).should be_true
              value.should eq(uuid)
            end
            executed.should be_true
          end
        end

        describe "BYTEA" do
          it "correctly saves and loads" do
            AllTypeModel.create!(bytea_f: Bytes[65, 114, 116, 105, 99, 108, 101])
            executed = false
            AllTypeModel.all.each_result_set do |rs|
              executed = true
              value = adapter.result_to_hash(rs)["bytea_f"]
              value.is_a?(Bytes).should be_true
              value.should eq(Bytes[65, 114, 116, 105, 99, 108, 101])
            end
            executed.should be_true
          end
        end

        describe "JSONB" do
          it "correctly saves and loads" do
            AllTypeModel.create!(jsonb_f: JSON.parse(%(["a", "b", 1])))
            executed = false
            AllTypeModel.all.each_result_set do |rs|
              executed = true
              value = adapter.result_to_hash(rs)["jsonb_f"]
              value.is_a?(JSON::PullParser).should be_true
              JSON::Any.new(value.as(JSON::PullParser)).should eq(JSON.parse(%(["a", "b", 1])))
            end
            executed.should be_true
          end
        end

        describe "POINT" do
          it "correctly saves and loads" do
            AllTypeModel.create!(point_f: PG::Geo::Point.new(1.2, 3.4))
            executed = false
            AllTypeModel.all.each_result_set do |rs|
              executed = true
              value = adapter.result_to_hash(rs)["point_f"]
              value.is_a?(PG::Geo::Point).should be_true
              value.should eq(PG::Geo::Point.new(1.2, 3.4))
            end
            executed.should be_true
          end
        end

        describe "PATH" do
          it "correctly saves and loads" do
            path = PG::Geo::Path.new([PG::Geo::Point.new(1.0, 2.0), PG::Geo::Point.new(3.0, 4.0)], closed: true)
            AllTypeModel.create!(path_f: path)
            executed = false
            AllTypeModel.all.each_result_set do |rs|
              executed = true
              value = adapter.result_to_hash(rs)["path_f"]
              value.is_a?(PG::Geo::Path).should be_true
              value.should eq(path)
            end
            executed.should be_true
          end
        end
      end
    end
  end

  describe "#result_to_array_by_names" do
    it "converts result set to array" do
      Factory.create_contact
      executed = false
      Contact.all.each_result_set do |rs|
        executed = true
        arr = adapter.result_to_array_by_names(rs, %w(name age))
        arr.size.should eq(2)
        arr[0].should eq("Deepthi")
        arr[1].should eq(28)
      end
      executed.should be_true
    end
  end
end
