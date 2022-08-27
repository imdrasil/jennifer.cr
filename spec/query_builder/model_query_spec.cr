require "../spec_helper"

pair_only do
  class WriteAddress < ApplicationRecord
    table_name "addresses"

    mapping({
      id:      Primary64,
      details: JSON::Any?,
      street:  String,
      main:    Bool,
    }, false)

    def self.write_adapter
      PAIR_ADAPTER
    end
  end
end

describe Jennifer::QueryBuilder::ModelQuery do
  adapter = Jennifer::Adapter.default_adapter

  describe "#relation" do
    # TODO: this should be tested under sql generating process
    it "makes join using relation scope" do
      adapter
        .sql_generator
        .select(Contact.all.relation(:addresses))
        .should match(/LEFT JOIN #{reg_quote_identifier("addresses")} ON #{reg_quote_identifier("addresses.contact_id")} = #{reg_quote_identifier("contacts.id")}/)
    end
  end

  describe "#destroy" do
    it "invokes #destroy of all model objects" do
      Factory.create_address(2)
      count = Address.destroy_counter
      Address.all.destroy
      Address.destroy_counter.should eq(count + 2)
    end

    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:id => 1, :street => "asd"})
        Query["addresses", adapter]
          .insert({:id => 1, :street => "asd", :created_at => Time.utc, :updated_at => Time.utc})
        Query["addresses", PAIR_ADAPTER].count.should eq(1)
        Query["addresses"].count.should eq(1)
        WriteAddress.all.destroy
        Query["addresses", PAIR_ADAPTER].count.should eq(0)
        Query["addresses"].count.should eq(1)
      end
    end
  end

  describe "#patch" do
    it "triggers validation" do
      Factory.create_contact(age: 20)
      Contact.all.patch(age: 12)
      Contact.all.where { _age == 12 }.exists?.should be_false
    end

    it do
      Factory.create_contact(age: 20)
      Contact.all.patch(age: 30)
      Contact.all.where { _age == 30 }.exists?.should be_true
    end

    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:id => 1, :street => "asd"})
        Query["addresses", adapter]
          .insert({:id => 1, :street => "asd", :created_at => Time.utc, :updated_at => Time.utc})
        Query["addresses", PAIR_ADAPTER].count.should eq(1)
        Query["addresses"].count.should eq(1)
        WriteAddress.all.patch(street: "qwe")
        Query["addresses", PAIR_ADAPTER].where { _street == "qwe" }.count.should eq(1)
        Query["addresses"].where { _street == "qwe" }.count.should eq(0)
      end
    end
  end

  describe "#patch!" do
    it "raises exception if is invalid" do
      Factory.create_contact(age: 20)
      expect_raises(Jennifer::RecordInvalid) do
        Contact.all.patch!(age: 12)
      end
    end

    it do
      Factory.create_contact(age: 20)
      Contact.all.patch!(age: 30)
      Contact.all.where { _age == 30 }.exists?.should be_true
    end
  end

  describe "#sql_args" do
    it "returns array of join and condition args" do
      Contact.where { _id == 2 }.join(Address) { _name == "asd" }.sql_args.should eq(db_array("asd", 2))
    end
  end

  describe "#to_a" do
    it "returns array of models" do
      Factory.create_contact(name: "a", age: 13)
      Factory.create_contact(name: "b", age: 14)
      res = Contact.all.to_a

      res.should be_a Array(Contact)
      res.size.should eq(2)
    end

    context "with nested objects" do
      it "builds nested objects" do
        c2 = Factory.create_contact(name: "b")
        Factory.create_passport(contact_id: c2.id, enn: "12345")
        res = Passport.all.join(Contact) { _id == _passport__contact_id }.with_relation(:contact).first!

        res.contact!.name.should eq("b")
      end

      context "none was called" do
        it "doesn't hit db and return empty array" do
          expect_query_silence do
            Contact.all.eager_load(:addresses).none.to_a.empty?.should be_true
          end
        end
      end

      context "when some records have no nested objects" do
        it "correctly build nested objects" do
          c1 = Factory.create_contact(name: "a")
          c2 = Factory.create_contact(name: "b")

          Factory.create_address(street: "a1 st.", contact_id: c1.id)
          Factory.create_address(street: "a2 st.", contact_id: c1.id)

          Factory.create_passport(contact_id: c2.id, enn: "12345")

          res = Contact.all
            .left_join(Address) { _contact_id == _contact__id }
            .left_join(Passport) { _contact_id == _contact__id }
            .order(id: :asc)
            .with_relation(:addresses, :passport).to_a

          res.size.should eq(2)

          res[0].addresses.size.should eq(2)
          res[1].addresses.size.should eq(0)
          res[0].passport.should be_nil
        end
      end

      context "retrieving several relation from same table" do
        it "uses auto aliasing" do
          c1 = Factory.create_contact(name: "a")
          Factory.create_contact(name: "b")

          Factory.create_address(main: false, contact_id: c1.id)
          Factory.create_address(main: false, contact_id: c1.id)
          Factory.create_address(main: true, contact_id: c1.id)

          r = Contact.all.eager_load(:addresses, :main_address).to_a
          r.size.should eq(2)
          r[0].addresses.size.should eq(3)
          r[0].main_address.nil?.should be_false
        end
      end
    end

    context "with includes" do
      it "loads all preloaded relations" do
        contacts = Factory.create_contact(3)
        a1 = Factory.create_address(contact_id: contacts[0].id)
        a2 = Factory.create_address(contact_id: contacts[1].id)
        f = Factory.create_facebook_profile(contact_id: contacts[1].id)
        res = Contact.all.includes(:addresses, :facebook_profiles).where { _id.in(contacts[0..1].map(&.id)) }.to_a

        res.size.should eq(2)
        res[0].addresses.map(&.id).should match_array([a1.id])
        res[1].addresses.map(&.id).should match_array([a2.id])
        res[1].facebook_profiles.map(&.id).should match_array([f.id])

        res[0].facebook_profiles.empty?.should be_true
      end
    end

    context "none was called" do
      it "doesn't hit db and return empty array" do
        expect_query_silence do
          Jennifer::Query["contacts"].none.to_a.empty?.should be_true
        end
      end
    end

    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:street => "asd"})
        Query["addresses", PAIR_ADAPTER].count.should eq(1)
        Query["addresses"].count.should eq(0)
        WriteAddress.all.to_a.should be_empty
      end
    end
  end

  describe "#find" do
    it "takes first record by given primary field value" do
      passport = Factory.create_passport
      Passport.all.find(passport.enn).not_nil!.enn.should eq(passport.enn)
    end

    it "returns nil if record isn't found" do
      Factory.create_passport(enn: "asd")
      Passport.all.find("as").should be_nil
    end
  end

  describe "#find!" do
    it "takes first record by given primary field value" do
      passport = Factory.create_passport
      Passport.all.find!(passport.enn).enn.should eq(passport.enn)
    end

    it "raises RecordNotFound if record isn't found" do
      Factory.create_passport(enn: "asd")
      expect_raises(::Jennifer::RecordNotFound) do
        Passport.all.find!("as")
      end
    end
  end

  describe "#find_by_sql" do
    query = "SELECT contacts.* FROM contacts"

    it "builds all requested objects" do
      Factory.create_contact
      res = Contact.all.find_by_sql(query)
      res.size.should eq(1)
      res[0].id.nil?.should be_false
    end

    it "raises exception if not all required fields are listed in the select clause" do
      Factory.create_contact
      _query = "SELECT id FROM contacts"
      expect_raises(Jennifer::BaseException, /includes only/) do
        Contact.all.find_by_sql(_query)
      end
    end

    it "respects none method" do
      Factory.create_contact
      res = Contact.all.none.find_by_sql(query)
      res.size.should eq(0)
    end

    it "preloads related objects if given" do
      c = Factory.create_contact
      Factory.create_address(contact_id: c.id)
      expect_queries_to_be_executed(2) do
        res = Contact.all.includes(:addresses).find_by_sql(query)
        res.size.should eq(1)
      end
      expect_query_silence { res[0].addresses.size.should eq(1) }
    end

    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:street => "asd"})
        Query["addresses", PAIR_ADAPTER].count.should eq(1)
        Query["addresses"].count.should eq(0)
        WriteAddress.all.find_by_sql("select * from addresses").size.should eq(0)
      end
    end
  end

  describe "#find_or_create_by" do
    it "finds record by given attributes" do
      record = Factory.create_contact(name: "John", age: 14)
      Contact.all.find_or_create_by({:name => "John", :age => 14}).id.should eq(record.id)
    end

    it "accepts string-key hash" do
      record = Factory.create_contact(name: "John", age: 14)
      Contact.all.find_or_create_by({"name" => "John", "age" => 14}).id.should eq(record.id)
    end

    it "respects existing query" do
      record = Factory.create_contact(name: "John", age: 14)
      Factory.create_contact(name: "John", age: 15)
      Contact.where({:age => 14}).order({:age => :desc}).find_or_create_by({:name => "John"}).id.should eq(record.id)
    end

    it "creates new record based on given hash" do
      Contact.all.find_or_create_by({:name => "John", :age => 14}).persisted?.should be_true
    end

    it "creates new record based on given block" do
      record = Contact.all.find_or_create_by({:name => "John"}) do |object|
        object.age = 13
      end
      record.persisted?.should be_true
      record.age.should eq(13)
      record.name.should eq("John")
    end

    it "does not raise validation error" do
      Contact.all.find_or_create_by({:name => "John", :age => 12}).persisted?.should be_false
    end
  end

  describe "#find_or_create_by!" do
    it "finds record by given attributes" do
      record = Factory.create_contact(name: "John", age: 14)
      Contact.all.find_or_create_by!({:name => "John", :age => 14}).id.should eq(record.id)
    end

    it "accepts string-key hash" do
      record = Factory.create_contact(name: "John", age: 14)
      Contact.all.find_or_create_by!({"name" => "John", "age" => 14}).id.should eq(record.id)
    end

    it "respects existing query" do
      record = Factory.create_contact(name: "John", age: 14)
      Factory.create_contact(name: "John", age: 15)
      Contact.where({:age => 14}).order({:age => :desc}).find_or_create_by!({:name => "John"}).id.should eq(record.id)
    end

    it "creates new record based on given hash" do
      Contact.all.find_or_create_by!({:name => "John", :age => 14}).persisted?.should be_true
    end

    it "creates new record based on given block" do
      record = Contact.all.find_or_create_by!({:name => "John"}) do |object|
        object.age = 13
      end
      record.persisted?.should be_true
      record.age.should eq(13)
      record.name.should eq("John")
    end

    it "raises validation error" do
      expect_raises(Jennifer::RecordInvalid) do
        Contact.all.find_or_create_by!({:name => "John", :age => 12})
      end
    end
  end

  describe "#find_or_initialize_by" do
    it "finds record by given attributes" do
      record = Factory.create_contact(name: "John", age: 14)
      Contact.all.find_or_initialize_by({:name => "John", :age => 14}).id.should eq(record.id)
    end

    it "accepts string-key hash" do
      record = Factory.create_contact(name: "John", age: 14)
      Contact.all.find_or_initialize_by({"name" => "John", "age" => 14}).id.should eq(record.id)
    end

    it "respects existing query" do
      record = Factory.create_contact(name: "John", age: 14)
      Factory.create_contact(name: "John", age: 15)
      Contact.where({:age => 14}).order({:age => :desc}).find_or_initialize_by({:name => "John"}).id
        .should eq(record.id)
    end

    it "initializes new record based on given hash" do
      Contact.all.find_or_initialize_by({:name => "John", :age => 14}).persisted?.should be_false
    end

    it "creates new record based on given block" do
      record = Contact.all.find_or_initialize_by({:name => "John"}) do |object|
        object.age = 13
      end
      record.persisted?.should be_false
      record.age.should eq(13)
      record.name.should eq("John")
    end
  end

  describe "#find_in_batches" do
    it "loads in batches without specifying primary key" do
      ids = Factory.create_contact(3).map(&.id)
      yield_count = 0
      Contact.all.find_in_batches(2, ids[1]) do |records|
        yield_count += 1
        records[0].id.should eq(ids[1])
        records[1].id.should eq(ids[2])
      end
      yield_count.should eq(1)
    end

    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:street => "asd"})
        Query["addresses", PAIR_ADAPTER].count.should eq(1)
        Query["addresses"].count.should eq(0)
        executed = false
        WriteAddress.all.find_in_batches { executed = true }
        executed.should be_false
      end
    end
  end

  describe "#find_each" do
    it "loads each in batches without specifying primary key" do
      ids = Factory.create_contact(3).map(&.id)
      buff = [] of Int64
      Contact.all.find_each(2, ids[1]) do |record|
        buff << record.id!
      end
      buff.should eq(ids[1..2])
    end

    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:street => "asd"})
        executed = false
        WriteAddress.all.find_each { executed = true }
        executed.should be_false
      end
    end
  end

  describe "#except" do
    it "creates new instance" do
      q = Contact.where { _id > 2 }
      q.except([""]).should_not eq(q)
    end

    it "creates equal object if nothing to exclude was given" do
      q = Contact.where { _id > 2 }
      clone = q.except([""])
      clone.eql?(q).should be_true
    end

    it "excludes having if given" do
      q = Contact.all.group(:age).having { _age > 20 }
      clone = q.except(["having"])
      clone._having.nil?.should be_true
    end

    it "excludes order if given" do
      q = Contact.all.order(age: "asc")
      clone = q.except(["order"])
      clone._order?.should be_falsey
    end

    it "excludes join if given" do
      q = Contact.all.join("passports") { _contact_id == _contacts__id }
      clone = q.except(["join"])
      clone._joins?.should be_falsey
    end

    it "excludes join if given" do
      q = Contact.all.union(Query["contacts"])
      clone = q.except(["union"])
      clone._unions?.should be_nil
    end

    it "excludes group if given" do
      q = Contact.all.group(:age)
      clone = q.except(["group"])
      clone._groups?.should be_falsey
    end

    it "excludes muting if given" do
      q = Contact.all.join("passports") { _contact_id == _contacts__id }
      clone = q.except(["none"])
      clone.eql?(q).should be_true
    end

    it "excludes select if given" do
      q = Contact.all.select { [_id] }
      clone = q.except(["select"])
      clone._select_fields.map(&.class).should eq([Jennifer::QueryBuilder::Star])
    end

    it "excludes where if given" do
      q = Contact.where { _age < 99 }
      clone = q.except(["where"])
      clone.as_sql.should_not match(/WHERE/)
    end

    it "expression builder follow newly created object" do
      q = Contact.all
      clone = q.except([""])
      clone.expression_builder.query.should eq(clone)
    end

    it "automatically ignores any relation usage" do
      q = Contact.all.eager_load(:addresses)
      clone = q.except([""])
      clone.with_relation?.should be_false
      clone._joins!.empty?.should be_false
    end
  end

  describe "#clone" do
    clone = Contact
      .where { _id > 2 }
      .group(:age)
      .having { _age > 2 }
      .order(age: "asc")
      .join("passports") { _contact_id == _contacts__id }
      .union(Query["contacts"])
      .select { [_id] }
      .eager_load(:addresses)
      .includes(:addresses)
      .clone
    query = clone.as_sql

    it { query.should match(/WHERE/) }
    it { query.should match(/GROUP/) }
    it { query.should match(/ORDER/) }
    it { query.should match(/JOIN/) }
    it { query.should match(/UNION/) }
    it { clone._select_fields[0].should_not be_a(Jennifer::QueryBuilder::Star) }
    it { clone.with_relation?.should be_true }
    pending "add more precise testing" { }
  end

  describe "complicated query example" do
    postgres_only do
      it "allows custom select with grouping" do
        Factory.create_contact
        Contact.all
          .select { [sql("count(*)").alias("stat_count"), sql("date_trunc('year', created_at)").alias("period")] }
          .group("period")
          .order({"period" => :desc})
          .results
          .size
          .should eq(1)
      end

      it "allows to use float for filtering decimal fields" do
        c = Factory.build_contact
        ballance = PG::Numeric.new(2i16, 0i16, 0i16, 1i16, [15i16, 1000i16])
        c.ballance = ballance
        c.save
        Contact.all.where { _ballance == 15.1 }.count.should eq(1)
      end
    end

    describe "CTE" do
      it do
        Jennifer::Query["cte"]
          .with(
            "cte",
            Jennifer::Query[""].select("1 as n")
              .union(Jennifer::Query["cte"].select("1 + n AS n").where { _n < 5 }, true),
            true
          )
          .db_results
          .flat_map(&.values)
          .should eq([1, 2, 3, 4, 5])
      end
    end
  end

  describe "#pluck" do
    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:street => "asd"})
        WriteAddress.all.pluck(:street).should be_empty
      end
    end
  end

  describe "#delete" do
    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:street => "asd"})
        Query["addresses", adapter].insert({:street => "asd", :created_at => Time.utc, :updated_at => Time.utc})
        Query["addresses", PAIR_ADAPTER].count.should eq(1)
        Query["addresses"].count.should eq(1)
        WriteAddress.all.delete
        Query["addresses", PAIR_ADAPTER].count.should eq(0)
        Query["addresses"].count.should eq(1)
      end
    end
  end

  describe "#exists?" do
    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:street => "asd"})
        WriteAddress.all.exists?.should be_false
      end
    end
  end

  describe "#insert" do
    pair_only do
      it "respects read/write adapters" do
        WriteAddress.all.insert({:street => "asd"})
        Query["addresses", PAIR_ADAPTER].count.should eq(1)
        Query["addresses"].count.should eq(0)
      end
    end
  end

  describe "#upsert" do
    pair_only do
      it "respects read/write adapters" do
        WriteAddress.all.upsert(%w(street), [["qwe"]], %w(street))
        Query["addresses", PAIR_ADAPTER].count.should eq(1)
        Query["addresses"].count.should eq(0)
      end
    end
  end

  describe "#update" do
    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:street => "asd"})
        Query["addresses", adapter].insert({:street => "asd", :created_at => Time.utc, :updated_at => Time.utc})
        WriteAddress.all.update({:street => "qwe"})
        Query["addresses", PAIR_ADAPTER].where { _street == "qwe" }.count.should eq(1)
        Query["addresses"].where { _street == "qwe" }.count.should eq(0)
      end
    end
  end

  describe "#db_results" do
    pair_only do
      it "respects read/write adapters" do
        Query["addresses", PAIR_ADAPTER].insert({:street => "asd"})
        WriteAddress.all.db_results.should be_empty
      end
    end
  end
end
