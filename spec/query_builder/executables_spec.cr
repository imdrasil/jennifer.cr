require "../spec_helper"

describe Jennifer::QueryBuilder::Executables do
  described_class = Jennifer::QueryBuilder::Query

  describe "#first" do
    it "returns first record" do
      c1 = Factory.create_contact(age: 15)
      Factory.create_contact(age: 15)

      r = Contact.all.first
      r.not_nil!.id.should eq(c1.id)
    end

    it "returns nil if there is no such records" do
      Contact.all.first.should be_nil
    end
  end

  describe "#first!" do
    it "returns first record" do
      c1 = Factory.create_contact(age: 15)
      Factory.create_contact(age: 15)

      r = Contact.all.first!
      r.id.should eq(c1.id)
    end

    it "raises error if there is no such records" do
      arg = db_specific(mysql: ->{ "?" }, postgres: ->{ "$1" })
      message = %(There is no record by given query:\nSELECT #{quote_identifier("contacts")}.* FROM #{quote_identifier("contacts")} WHERE #{quote_identifier("contacts.id")} > #{arg}  | [2])
      expect_raises(Jennifer::RecordNotFound, message) do
        Contact.all.where { _id > 2 }.first!
      end
    end
  end

  describe "#find_by" do
    it "returns matched record" do
      record = Factory.create_contact(name: "John", age: 14)
      Factory.create_contact(name: "John", age: 13)
      Query["contacts"].find_by({:name => "John", :age => 14}).not_nil!.id.should eq(record.id)
    end

    it "returns nil if nothing matches" do
      Query["contacts"].find_by({:name => "John", :age => 14}).should be_nil
    end
  end

  describe "#find_by!" do
    it "returns matched record" do
      record = Factory.create_contact(name: "John", age: 14)
      Factory.create_contact(name: "John", age: 13)
      Query["contacts"].find_by!({:name => "John", :age => 14}).id.should eq(record.id)
    end

    it "raises an exception if no record found" do
      expect_raises(Jennifer::RecordNotFound, /There is no record by given query/) do
        Query["contacts"].find_by!({:name => "John", :age => 14})
      end
    end
  end

  describe "#last" do
    it "inverse all orders" do
      c1 = Factory.create_contact(age: 15)
      Factory.create_contact(age: 16)

      r = Contact.all.order(age: :desc).last.not_nil!
      r.id.should eq(c1.id)
    end

    it "add order by primary key if no order was specified" do
      Factory.create_contact(age: 15)
      c2 = Factory.create_contact(age: 16)

      r = Contact.all.last.not_nil!
      r.id.should eq(c2.id)
    end
  end

  describe "#last!" do
    it "returns last record" do
      Factory.create_contact(age: 15)
      c2 = Factory.create_contact(age: 15)

      r = Contact.all.last!
      r.id.should eq(c2.id)
    end

    it "raises error if there is no such records" do
      expect_raises(Jennifer::RecordNotFound) do
        Contact.all.last!
      end
    end
  end

  describe "#pluck" do
    it "converts time zones to configured" do
      AllTypeModel.create!(timestamp_f: Time.local(2020, 10, 10, 20, 10, 12, location: local_time_zone))
      res = Query["all_types"].pluck(:timestamp_f)
      res[0].should eq(Time.local(2020, 10, 10, 20, 10, 12, location: local_time_zone))
    end

    it "doesn't convert time zones to application zone if time_zone_aware_attributes is off" do
      AllTypeModel.create!(timestamp_f: Time.local(2020, 10, 10, 20, 10, 12, location: local_time_zone))
      Jennifer::Config.time_zone_aware_attributes = false
      res = Query["all_types"].pluck(:timestamp_f)
      res[0].should eq(Time.local(2020, 10, 10, 17, 10, 12, location: local_time_zone))
    end

    context "with list of attributes" do
      it "returns array of arrays" do
        Factory.create_contact(name: "a", age: 13)
        Factory.create_contact(name: "b", age: 14)
        res = Query["contacts"].pluck(:name, :age)
        res.size.should eq(2)
        res[0][0].should eq("a")
        res[1][1].should eq(14)
      end
    end

    context "with one argument" do
      it "correctly extracts json" do
        Factory.create_address(details: JSON.parse({:city => "Duplin"}.to_json))
        value = Query["addresses"].pluck(:details)[0]
        db_specific(
          mysql: ->{ value.should be_a(JSON::Any) },
          postgres: ->{ value.should be_a(JSON::PullParser) }
        )
      end

      it "accepts plain SQL" do
        Factory.create_contact(name: "a", age: 13)
        res = Query["contacts"].select("COUNT(id) + 1 as test").pluck(:test)
        res[0].should eq(2)
      end
    end

    context "with array of attributes" do
      it "returns array of arrays" do
        Factory.create_contact(name: "a", age: 13)
        Factory.create_contact(name: "b", age: 14)
        res = Query["contacts"].pluck([:name, :age])
        res.size.should eq(2)
        res[0][0].should eq("a")
        res[1][1].should eq(14)
      end
    end

    context "with splatted named tuple" do
      it "returns array of named tuples of given type" do
        Factory.create_contact(name: "a", age: 13)
        Factory.create_contact(name: "b", age: 14)
        res = Query["contacts"].pluck(name: String, age: Int32)
        res.size.should eq(2)
        res[0][:name].should eq("a")
        res[1][:age].should eq(14)
        typeof(res[1]).should eq(NamedTuple(name: String, age: Int32))
      end

      it "returns an empty array if there is no record" do
        res = Query["contacts"].pluck(name: String, age: Int32)
        res.size.should eq(0)
        typeof(res).should eq(Array(NamedTuple(name: String, age: Int32)))
      end
    end

    context "when select is already specified" do
      it "respects raw SQL" do
        Factory.create_contact(name: "a", age: 13)
        res = Query["contacts"].select("age * 2 as test, name").pluck(:test)
        res[0].should eq(26)
      end

      it "respects array of criteria specified to select" do
        Factory.create_contact(name: "a", age: 13)
        res = Query["contacts"].select { [sql("age * 2").alias("age")] }.pluck(:age)
        res[0].should eq(26)
      end
    end
  end

  describe "#delete" do
    it "deletes from db using existing conditions" do
      count = Contact.all.count
      Factory.create_contact(name: "Extra content")
      Contact.all.count.should eq(count + 1)
      described_class.new("contacts").where { _name == "Extra content" }.delete
      Contact.all.count.should eq(count)
    end
  end

  describe "#exists?" do
    it "returns true if there is such object with given condition" do
      Factory.create_contact(name: "Anton")
      described_class.new("contacts").where { _name == "Anton" }.exists?.should be_true
    end

    it "returns false if there is no such object with given condition" do
      Factory.create_contact(name: "Anton")
      described_class.new("contacts").where { _name == "Abraham" }.exists?.should be_false
    end
  end

  describe "#insert" do
    context "with array" do
      it do
        values = [["John", 60], ["Cris", 111]]
        Query["contacts"].insert(%w(name age), values)
        Query["contacts"].pluck(:name, :age).should eq(values)
      end
    end

    context "with hash" do
      it do
        values = {:name => "John", :age => 60}
        Query["contacts"].insert(values)
        Query["contacts"].pluck(:name, :age).should eq([values.values])
      end
    end

    context "with named tuple" do
      it do
        values = {name: "John", age: 60}
        Query["contacts"].insert(values)
        Query["contacts"].pluck(:name, :age).should eq([values.values.to_a])
      end
    end

    describe "do_nothing" do
      it do
        values = {name: "John", age: 60}
        Query["contacts"].none.insert(values)
        Query["contacts"].pluck(:name, :age).should be_empty
      end
    end
  end

  describe "#upsert" do
    context "with block" do
      it do
        Factory.create_contact(name: "Ivan", age: 15, description: "desc")
        values = [["John", 60, "desc"]]
        Query["contacts"].upsert(%w(name age description), values, %w(description)) { {:age => 1, :name => "a"} }
        Query["contacts"].pluck(:name, :age, :description).should eq([["a", 1, "desc"]])
      end

      context "with reference to values" do
        it do
          Factory.create_contact(name: "Ivan", age: 15, description: "desc")
          values = [["John", 60, "desc"]]
          Query["contacts"].upsert(%w(name age description), values, %w(description)) { {:age => values(:age) + 1, :name => "a"} }
          Query["contacts"].pluck(:name, :age, :description).should eq([["a", 61, "desc"]])
        end
      end
    end

    context "without block" do
      it "do nothing" do
        Factory.create_contact(name: "Ivan", age: 15, description: "desc")
        values = [["John", 60, "desc"]]
        Query["contacts"].upsert(%w(name age description), values, %w(description))
        Query["contacts"].pluck(:name, :age, :description).should eq([["Ivan", 15, "desc"]])
      end
    end
  end

  describe "#update" do
    it "updates given fields in all matched rows" do
      Factory.create_contact(age: 13, name: "a")
      Factory.create_contact(age: 14, name: "a")
      Factory.create_contact(age: 15, name: "a")

      Contact.where { _age < 15 }.update({:age => 20, :name => "b"})
      Contact.where { (_age == 20) & (_name == "b") }.count.should eq(2)
    end

    context "with block" do
      it do
        c1 = Factory.create_contact(age: 13, name: "a")
        Factory.create_contact(age: 14, name: "a")
        Factory.create_contact(age: 15, name: "a")

        Contact.where { _age < 15 }.update do
          {
            :age  => _age - 1,
            :name => "b",
          }
        end

        c1.reload
        c1.name.should eq("b")
        c1.age.should eq(12)
      end
    end
  end

  describe "#increment" do
    it "accepts hash" do
      c = Factory.create_contact(name: "asd", gender: "male", age: 18)
      Contact.where { _id == c.id }.increment({:age => 2})
      c.reload.age.should eq(20)
    end

    it "accepts named tuple literal" do
      c = Factory.create_contact(name: "asd", gender: "male", age: 18)
      Contact.where { _id == c.id }.increment(age: 2)
      c.reload.age.should eq(20)
    end
  end

  describe "#decrement" do
    it "accepts hash" do
      c = Factory.create_contact(name: "asd", gender: "male", age: 20)
      Contact.where { _id == c.id }.decrement({:age => 2})
      c.reload.age.should eq(18)
    end

    it "accepts named tuple literal" do
      c = Factory.create_contact({:name => "asd", :gender => "male", :age => 20})
      Contact.where { _id == c.id }.decrement(age: 2)
      c.reload.age.should eq(18)
    end
  end

  describe "#to_a" do
    context "with #none" do
      it "doesn't hit db and return empty array" do
        expect_query_silence do
          Jennifer::Query["contacts"].none.to_a.empty?.should be_true
        end
      end
    end
  end

  describe "#db_results" do
    describe "without FROM clause" do
      it do
        Query[""].select("1 as col").db_results[0].should eq({"col" => 1})
      end
    end

    it "returns array of hashes" do
      id = Factory.create_contact.id
      res = Contact.all.db_results
      res.is_a?(Array).should be_true
      res[0]["id"].should eq(id)
    end
  end

  describe "#results" do
    it "returns array of records" do
      Contact.all.results.should eq([] of Jennifer::Record)
    end

    pair_only do
      it "respects specified adapter" do
        Factory.create_address
        PairAddress.create!
        PairAddress.create!
        Query["addresses"].count.should eq(1)
        Query["addresses", PAIR_ADAPTER].count.should eq(2)
      end
    end
  end

  describe "#ids" do
    it "returns array of ids" do
      id = Factory.create_contact.id
      ids = Contact.all.ids
      ids.should be_a(Array(Int64))
      ids.should eq([id])
    end

    it "raises BadQuery if there is no id field" do
      expect_raises(Jennifer::BadQuery) do
        Passport.all.ids
      end
    end
  end

  describe "#each" do
    it "yields each found row" do
      Factory.create_contact(name: "a", age: 13)
      Factory.create_contact(name: "b", age: 14)
      i = 13
      Contact.all.order(age: :asc).each do |record|
        record.age.should eq(i)
        i += 1
      end
      i.should eq(15)
    end
  end

  describe "#each_result_set" do
    it "yields rows from result set" do
      Factory.create_contact(name: "a", age: 13)
      Factory.create_contact(name: "b", age: 14)

      i = 0
      Contact.all.each_result_set do |rs|
        rs.should be_a DB::ResultSet
        Contact.new(rs)
        i += 1
      end
      i.should eq(2)
    end
  end

  describe "#find_in_batches" do
    query = Query["contacts"]

    context "with primary field" do
      context "as criteria" do
        pk = Factory.build_criteria(table: "contacts", field: "id")

        it "yields proper amount of records" do
          Factory.create_contact(3)
          executed = false
          query.find_in_batches(batch_size: 2, primary_key: pk) do |records|
            executed = true
            records.size.should eq(2)
            break
          end
          executed.should be_true
        end

        it "yields proper amount of times" do
          Factory.create_contact(3)
          yield_count = 0
          query.find_in_batches(batch_size: 2, primary_key: pk) do
            yield_count += 1
          end
          yield_count.should eq(2)
        end

        it "use 'start' argument as start primary key value" do
          yield_count = 0
          ids = Factory.create_contact(3).map(&.id)
          query.find_in_batches(pk, 2, ids[1]) do |records|
            yield_count += 1
            records[0].id.should eq(ids[1])
            records[1].id.should eq(ids[2])
          end
          yield_count.should eq(1)
        end
      end

      context "as string" do
        it "properly loads records" do
          Factory.create_contact(3)
          yield_count = 0
          query.find_in_batches("id", 2) do
            yield_count += 1
          end
          yield_count.should eq(2)
        end
      end
    end

    context "without primary key" do
      it "uses 'start' as a page number" do
        Factory.create_contact(3)
        yield_count = 0
        query.find_in_batches(batch_size: 2, start: 1) do
          yield_count += 1
        end
        yield_count.should eq(1)
      end
    end
  end

  describe "#find_each" do
    query = Query["contacts"]

    context "with primary field" do
      context "as criteria" do
        pk = Factory.build_criteria(table: "contacts", field: "id")

        it "yields record" do
          Factory.create_contact(3)
          executed = false
          query.find_each(pk, 2) do |record|
            executed = true
            record.is_a?(Jennifer::Record).should be_true
            break
          end
          executed.should be_true
        end

        it "yields proper times" do
          Factory.create_contact(3)
          yield_count = 0
          query.find_each(batch_size: 2, primary_key: pk) do
            yield_count += 1
          end
          yield_count.should eq(3)
        end

        it "use 'start' argument as start primary key value" do
          ids = Factory.create_contact(3).map(&.id)
          buff = [] of Int64
          query.find_each(pk, 2, ids[1]) do |record|
            buff << record.id(Int64)
          end
          buff.should eq(ids[1..2])
        end
      end

      context "as string" do
        it "properly loads records" do
          Factory.create_contact(3)
          yield_count = 0
          query.find_each("id", 2) do
            yield_count += 1
          end
          yield_count.should eq(3)
        end
      end
    end

    context "without primary key" do
      it "uses 'start' as a page number" do
        Factory.create_contact(3)
        yield_count = 0
        query.find_each(batch_size: 2, start: 1) do
          yield_count += 1
        end
        yield_count.should eq(1)
      end
    end
  end

  describe "#find_records_by_sql" do
    query = <<-SQL
      SELECT contacts.*
      FROM contacts
    SQL

    it "builds all requested objects" do
      Factory.create_contact
      res = Query["contacts"].find_records_by_sql(query)
      res.size.should eq(1)
      res[0].name.should eq("Deepthi")
    end

    it "accepts arguments" do
      Factory.create_contact(age: 21)
      Factory.create_contact(age: 20)
      placeholder = db_specific(postgres: ->{ "$1" }, mysql: ->{ "?" })
      res = Query["contacts"].find_records_by_sql(
        "SELECT * FROM contacts WHERE age > #{placeholder}",
        [20]
      )
      res.size.should eq(1)
      res[0].age.should eq(21)
    end

    it "respects #none" do
      Factory.create_contact
      res = Query["contacts"].none.find_records_by_sql(query)
      res.size.should eq(0)
    end
  end

  describe "#explain" do
    it { Query["contacts"].explain.should_not be_empty }
  end
end
