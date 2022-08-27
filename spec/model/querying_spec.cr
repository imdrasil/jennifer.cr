require "../spec_helper"

describe Jennifer::Model::Querying do
  describe "#where" do
    it do
      record = Factory.create_contact(age: 14)
      Factory.create_contact(age: 15)
      Contact.where { _age == 14 }.to_a.map(&.id).should eq([record.id])
    end

    it do
      record = Factory.create_contact(age: 14)
      Factory.create_contact(age: 15)
      Contact.where({:age => 14}).to_a.map(&.id).should eq([record.id])
    end
  end

  describe "#select" do
    it do
      Factory.create_contact(age: 14)
      Contact.select(:age).results.map(&.age).should eq([14])
      Contact.select(Contact._age).results.map(&.age).should eq([14])
    end

    it do
      Factory.create_contact(age: 14)
      Contact.select { [_age] }.results.map(&.age).should eq([14])
    end
  end

  describe "#from" do
    it do
      Factory.create_contact(age: 14)
      User.from("contacts").select("*").results.map(&.age).should eq([14])
    end
  end

  describe "#having" do
    it do
      Factory.create_contact(name: "Ivan", age: 15)
      Factory.create_contact(name: "Max", age: 19)
      Factory.create_contact(name: "Ivan", age: 50)

      res = Contact.having { sql("COUNT(id)") > 1 }
        .select("COUNT(id) as count, contacts.name")
        .group("name")
        .pluck(:name)
      res.size.should eq(1)
      res[0].should eq("Ivan")
    end
  end

  describe "#union" do
    it "adds query to own array of unions" do
      c = Factory.create_contact
      country = Factory.create_country
      Contact.union(Country.select(:id).order { [sql("id").asc] })
        .pluck(:id)
        .should eq([c.id.not_nil!, country.id.not_nil!].sort)
    end
  end

  describe "#distinct" do
    it "adds DISTINCT to SELECT clause" do
      Factory.create_contact(age: 15)
      Factory.create_contact(age: 15)
      Contact.distinct.select(:age).results.map(&.age).should eq([15])
    end
  end

  describe "#group" do
    it do
      Factory.create_contact(name: "Ivan", age: 15)
      Factory.create_contact(name: "Max", age: 19)
      Factory.create_contact(name: "Ivan", age: 50)

      res = Contact.group("name")
        .select("COUNT(id) as count, contacts.name")
        .having { sql("COUNT(id)") > 1 }
        .pluck(:name)
      res.size.should eq(1)
      res[0].should eq("Ivan")
    end

    it do
      Factory.create_contact(name: "Ivan", age: 15)
      Factory.create_contact(name: "Max", age: 19)
      Factory.create_contact(name: "Ivan", age: 50)

      res = Contact.group { [_name] }
        .select("COUNT(id) as count, contacts.name")
        .having { sql("COUNT(id)") > 1 }
        .pluck(:name)
      res.size.should eq(1)
      res[0].should eq("Ivan")
    end
  end

  describe "#merge" do
    it do
      record = Factory.create_contact(name: "John", age: 15)
      Factory.create_contact(name: "April", age: 15)
      Contact.merge(Contact.where({:name => "John"})).where { _age == 15 }.to_a.map(&.id).should eq([record.id])
    end
  end

  describe "#limit" do
    it do
      record = Factory.create_contact(name: "John", age: 15)
      Factory.create_contact(name: "April", age: 15)
      Contact.limit(1).to_a.map(&.id).should eq([record.id])
    end
  end

  describe "#offset" do
    it do
      record = Factory.create_contact(name: "John", age: 15)
      Factory.create_contact(name: "April", age: 15)
      Contact.offset(1).limit(1).order(id: :desc).to_a.map(&.id).should eq([record.id])
    end
  end

  describe "#count" do
    it do
      Factory.create_contact(name: "John", age: 15)
      Factory.create_contact(name: "April", age: 15)
      Contact.count.should eq(2)
    end
  end

  describe "#order" do
    it do
      records = [Factory.create_contact(name: "John", age: 15), Factory.create_contact(name: "April", age: 14)]
      Contact.order(age: :desc).to_a.map(&.id).should eq(records.map(&.id))
    end

    it do
      records = [Factory.create_contact(name: "John", age: 15), Factory.create_contact(name: "April", age: 14)]
      Contact.order { [_age.desc] }.to_a.map(&.id).should eq(records.map(&.id))
    end
  end

  describe "#reorder" do
    it do
      records = [Factory.create_contact(name: "John", age: 15), Factory.create_contact(name: "April", age: 14)]
      Contact.reorder(age: :desc).to_a.map(&.id).should eq(records.map(&.id))
    end

    it do
      records = [Factory.create_contact(name: "John", age: 15), Factory.create_contact(name: "April", age: 14)]
      Contact.reorder { [_age.desc] }.to_a.map(&.id).should eq(records.map(&.id))
    end
  end

  describe "#join" do
    it do
      contact = Factory.create_contact
      Factory.create_contact
      Factory.create_address(contact_id: contact.id)
      Contact.join(Address) { |t| _contact_id == t._id }.to_a.map(&.id).should eq([contact.id])
    end
  end

  describe "#find_in_batches" do
    it "loads in batches without specifying primary key" do
      ids = Factory.create_contact(3).map(&.id)
      yield_count = 0
      Contact.find_in_batches(2, ids[1]) do |records|
        yield_count += 1
        records[0].id.should eq(ids[1])
        records[1].id.should eq(ids[2])
      end
      yield_count.should eq(1)
    end
  end
end
