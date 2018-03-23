require "../spec_helper"

describe Jennifer::Adapter::ResultParsers do
  adapter = Jennifer::Adapter.default_adapter
  contact_fields = db_specific(
    postgres: -> { %w(id name age tags ballance gender created_at updated_at description user_id) },
    mysql: -> { %w(id name age ballance gender created_at updated_at description user_id) }
  )

  describe "#result_to_hash" do
    it "converts result set to hash with string keys" do
      Factory.create_contact
      executed = false
      Contact.all.each_result_set do |rs|
        executed = true
        hash = adapter.result_to_hash(rs)
        hash.keys.should eq(contact_fields)
        hash["id"].should_not be_nil
        hash["name"].should eq("Deepthi")
        hash["age"].should eq(28)
      end
      executed.should be_true
    end
  end

  describe "#result_to_array" do
    it "converts result set to array" do
      Factory.create_contact
      executed = false
      Contact.all.each_result_set do |rs|
        executed = true
        array = adapter.result_to_array(rs)
        array.size.should eq(contact_fields.size)
        array[0].should_not be_nil
        array[1].should eq("Deepthi")
        array[2].should eq(28)
      end
      executed.should be_true
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
