require "../spec_helper"

def get_record
  result = nil
  Factory.create_contact(name: "Jennifer", age: 20)
  Contact.all.each_result_set do |rs|
    result = Jennifer::Record.new(Jennifer::Adapter.default_adapter.result_to_hash(rs))
  end
  result.not_nil!
end

describe Jennifer::Record do
  described_class = Jennifer::Record

  describe "#initialize" do
    context "from hash" do
      it "loads without errors" do
        hash = {} of String => Jennifer::DBAny
        hash["name"] = "qweqwe"
        hash["age"] = 1
        described_class.new(hash)
      end
    end
  end

  describe "auto generated getter" do
    context "without type casting" do
      it "generates methods" do
        record = get_record
        record.name.should eq("Jennifer")
      end
    end

    context "with type casting" do
      it "generates method" do
        get_record.name(String).should eq("Jennifer")
      end
    end

    it "raises Jennifer::BaseException if no key is defined" do
      expect_raises(Jennifer::BaseException) do
        get_record.unknown_field
      end
    end
  end

  describe "#[]" do
    it "returns field by given key" do
      get_record["name"].should eq("Jennifer")
    end
  end

  describe "#attribute" do
    context "without typecasting" do
      it "returns value of any type" do
        value = get_record.attribute("name")
        value.should eq("Jennifer")
        typeof(value).should eq(Jennifer::DBAny)
      end
    end

    context "with typecasting" do
      it "returns value casted to the given type" do
        value = get_record.attribute("name", String)
        value.should eq("Jennifer")
        typeof(value).should eq(String)
      end
    end
  end

  describe "#to_json" do
    it "includes all fields by default" do
      record = get_record
      target_hash = db_specific(
        mysql: ->do
          {
            :id          => record.id,
            :name        => record.name,
            :age         => record.age,
            :ballance    => nil,
            :gender      => record.gender,
            :created_at  => record.created_at,
            :updated_at  => record.updated_at,
            :description => nil,
            :user_id     => nil,
            :email       => nil,
          }
        end,
        postgres: ->do
          {
            :id          => record.id,
            :name        => record.name,
            :age         => record.age,
            :tags        => nil,
            :ballance    => nil,
            :gender      => record.gender,
            :created_at  => record.created_at,
            :updated_at  => record.updated_at,
            :description => nil,
            :user_id     => nil,
            :email       => nil,
          }
        end
      )
      record.to_json.should eq(target_hash.to_json)
    end

    it "allows to specify *only* argument solely" do
      record = get_record
      record.to_json(%w[id]).should eq(%({"id":#{record.id}}))
    end

    it "allows to specify *except* argument solely" do
      record = get_record
      target_hash = db_specific(
        mysql: ->do
          {
            :name        => record.name,
            :age         => record.age,
            :ballance    => nil,
            :gender      => record.gender,
            :created_at  => record.created_at,
            :updated_at  => record.updated_at,
            :description => nil,
            :user_id     => nil,
            :email       => nil,
          }
        end,
        postgres: ->do
          {
            :name        => record.name,
            :age         => record.age,
            :tags        => nil,
            :ballance    => nil,
            :gender      => record.gender,
            :created_at  => record.created_at,
            :updated_at  => record.updated_at,
            :description => nil,
            :user_id     => nil,
            :email       => nil,
          }
        end
      )
      record.to_json(except: %w[id]).should eq(target_hash.to_json)
    end

    context "with block" do
      it "allows to extend json using block" do
        executed = false
        record = get_record
        target_hash = db_specific(
          mysql: ->do
            {
              :id          => record.id,
              :name        => record.name,
              :age         => record.age,
              :ballance    => nil,
              :gender      => record.gender,
              :created_at  => record.created_at,
              :updated_at  => record.updated_at,
              :description => nil,
              :user_id     => nil,
              :email       => nil,
              :custom      => "value",
            }
          end,
          postgres: ->do
            {
              :id          => record.id,
              :name        => record.name,
              :age         => record.age,
              :tags        => nil,
              :ballance    => nil,
              :gender      => record.gender,
              :created_at  => record.created_at,
              :updated_at  => record.updated_at,
              :description => nil,
              :user_id     => nil,
              :email       => nil,
              :custom      => "value",
            }
          end
        )
        record.to_json do |json, obj|
          executed = true
          obj.should eq(record)
          json.field "custom", "value"
        end.should eq(target_hash.to_json)
        executed.should be_true
      end

      it "respects :only option" do
        record = get_record
        record.to_json(%w[id]) do |json|
          json.field "custom", "value"
        end.should eq({id: record.id, custom: "value"}.to_json)
      end

      it "respects :except option" do
        record = get_record
        target_hash = db_specific(
          mysql: ->do
            {
              :name        => record.name,
              :age         => record.age,
              :ballance    => nil,
              :gender      => record.gender,
              :created_at  => record.created_at,
              :updated_at  => record.updated_at,
              :description => nil,
              :user_id     => nil,
              :email       => nil,
              :custom      => "value",
            }
          end,
          postgres: ->do
            {
              :name        => record.name,
              :age         => record.age,
              :tags        => nil,
              :ballance    => nil,
              :gender      => record.gender,
              :created_at  => record.created_at,
              :updated_at  => record.updated_at,
              :description => nil,
              :user_id     => nil,
              :email       => nil,
              :custom      => "value",
            }
          end
        )

        record.to_json(except: %w[id]) do |json|
          json.field "custom", "value"
        end.should eq(target_hash.to_json)
      end
    end
  end
end
