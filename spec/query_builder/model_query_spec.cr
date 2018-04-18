require "../spec_helper"

# TODO: add checking for log entries when we shouldn't hit db

describe Jennifer::QueryBuilder::ModelQuery do
  describe "#with" do
    it "adds to select clause given relation" do
      q1 = Contact.all.relation(:addresses)
      q1.with(:addresses)
      select_clause(q1).should match(/SELECT contacts\.\*, addresses\.\*/)
    end

    it "raises error if given relation is not exists" do
      q1 = Contact.all
      expect_raises(Jennifer::UnknownRelation, "Unknown relation for Contact: relation") do
        q1.relation(:addresses).with(:relation)
        select_clause(q1)
      end
    end

    it "raises error if given relation is not joined" do
      expect_raises(Jennifer::BaseException, /with should be called after correspond join/) do
        select_clause(Contact.all.with(:addresses))
      end
    end
  end

  describe "#eager_load" do
    describe "inverse_of" do
      it "loads relation as well" do
        c1 = Factory.create_contact(name: "asd")
        Factory.create_address(contact_id: c1.id, street: "asd st.")

        res = Contact.all.eager_load(:addresses).first!
        res.addresses[0].street.should eq("asd st.")
      end

      it "sets all deep relations" do
        c = Factory.create_contact(name: "contact 1")
        Factory.create_address(contact_id: c.id, street: "some st.")
        country = Factory.create_country
        Factory.create_city(country_id: country.id)
        c.add_countries(country)

        res = City.all.eager_load(country: {:contacts => [:addresses]}).to_a
        expect_query_silence do
          res[0].country!.contacts[0].addresses[0].contact
        end
      end
    end

    context "with nested relation defined as symbol" do
      it do
        c = Factory.create_contact(name: "contact 1")
        Factory.create_address(contact_id: c.id, street: "some st.")
        country = Factory.create_country
        Factory.create_city(country_id: country.id)
        c.add_countries(country)

        res = Contact.all.eager_load(:addresses, :passport, countries: :cities).to_a
        expect_query_silence do
          res.size.should eq(1)
          res[0].addresses.size.should eq(1)
          res[0].passport.should be_nil
          res[0].countries.size.should eq(1)
          res[0].countries[0].cities.size.should eq(1)
        end
      end
    end

    context "with nested relation defined as array" do
      it do
        c = Factory.create_contact(name: "contact 1")
        Factory.create_address(contact_id: c.id, street: "some st.")
        country = Factory.create_country
        Factory.create_city(country_id: country.id)
        c.add_countries(country)

        res = Contact.all.eager_load(:addresses, :passport, countries: [:cities]).to_a
        expect_query_silence do
          res.size.should eq(1)
          res[0].addresses.size.should eq(1)
          res[0].passport.should be_nil
          res[0].countries.size.should eq(1)
          res[0].countries[0].cities.size.should eq(1)
        end
      end
    end

    context "with nested relation defined as hash" do
      it do
        c = Factory.create_contact(name: "contact 1")
        Factory.create_address(contact_id: c.id, street: "some st.")
        country = Factory.create_country
        Factory.create_city(country_id: country.id)
        c.add_countries(country)

        res = City.all.eager_load(country: {:contacts => [:addresses, :passport]}).to_a
        expect_query_silence do
          res.size.should eq(1)
          res[0].country!.contacts.size.should eq(1)
          res[0].country!.contacts[0].addresses.size.should eq(1)
          res[0].country!.contacts[0].passport.should be_nil
        end
      end
    end

    context "when object belongs to several parent objects" do
      it do
        country = Factory.create_country
        Factory.create_city(name: "c1", country_id: country.id)
        Factory.create_city(name: "c2", country_id: country.id)

        res = City.all.eager_load(:country).to_a
        expect_query_silence do
          res.size.should eq(2)
          res[0].country!.id.should eq(country.id)
          res[0].country!.same?(res[1].country).should be_true
        end
      end
    end

    context "target class defines not all fields and has non strict mapping" do
      it "loads both target class fields and included ones" do
        contacts = Factory.create_contact(3)
        ids = contacts.map(&.id)
        Factory.create_address(contact_id: contacts[0].id)

        res = ContactWithDependencies.all.eager_load(:addresses).where { _id.in(ids) }.order(id: :asc).to_a
        res.size.should eq(3)
        res[0].addresses.size.should eq(1)
        res[0].name.nil?.should be_false
      end
    end

    context "related model has own request" do
      # TODO: move it to SqlGenerator
      it "it generates proper request" do
        contact = Factory.create_contact
        query = Contact.all.eager_load(:main_address)
        Jennifer::Adapter.adapter.sql_generator.select(query).should match(/addresses\.main/)
      end
    end

    context "with defined inverse_of" do
      it "sets owner during building collection" do
        c = Factory.create_contact
        a = Factory.create_address(contact_id: c.id)
        expect_queries_to_be_executed(1) do
          res = Contact.all.eager_load(:addresses).to_a
          res[0].addresses[0].contact
        end
      end
    end

    it "properly loads several relations from the same table" do
      c = Factory.create_contact
      a = Factory.create_address(contact_id: c.id, main: false)
      main_address = Factory.create_address(contact_id: c.id, main: true)
      expect_queries_to_be_executed(1) do
        res = Contact.all.eager_load(:addresses, :main_address).to_a
        res[0].addresses.size.should eq(2)
        res[0].main_address!.id.should eq(main_address.id)
      end
    end

    it "stops reloading relation from db if there is no records" do
      Factory.create_contact
      c = Contact.all.eager_load(:addresses).to_a
      expect_query_silence do
        c[0].addresses
      end
    end

    it "stop reloading relation from the db if it is already loaded" do
      c = Factory.create_contact
      Factory.create_address(contact_id: c.id)
      c = Contact.all.eager_load(:addresses).to_a
      expect_query_silence do
        c[0].addresses.size.should eq(1)
      end
    end

    describe "one-to-many relation" do
      it do
        c = Factory.create_contact
        Factory.create_address(contact_id: c.id)
        Factory.create_address(contact_id: c.id)
        executed_times = 0
        Address.all.eager_load(:contact).to_a.each do |address|
          executed_times += 1
          address.contact.should_not be_nil
        end
        executed_times.should eq(2)
      end
    end
  end

  describe "#relation" do
    # TODO: this should be tested under sql generating process
    it "makes join using relation scope" do
      ::Jennifer::Adapter.adapter.sql_generator
                                 .select(Contact.all.relation(:addresses))
                                 .should match(/LEFT JOIN addresses ON addresses.contact_id = contacts.id/)
    end
  end

  describe "#destroy" do
    it "invokes destroy of all model objects" do
      Factory.create_address(2)
      count = Address.destroy_counter
      Address.all.destroy
      Address.destroy_counter.should eq(count + 2)
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

  describe "#select_args" do
    it "returns array of join and condition args" do
      Contact.where { _id == 2 }.join(Address) { _name == "asd" }.select_args.should eq(db_array("asd", 2))
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
        p = Factory.create_passport(contact_id: c2.id, enn: "12345")
        res = Passport.all.join(Contact) { _id == _passport__contact_id }.with(:contact).first!

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

          a1 = Factory.create_address(street: "a1 st.", contact_id: c1.id)
          a2 = Factory.create_address(street: "a2 st.", contact_id: c1.id)

          p = Factory.create_passport(contact_id: c2.id, enn: "12345")

          res = Contact.all.left_join(Address) { _contact_id == _contact__id }
                           .left_join(Passport) { _contact_id == _contact__id }
                           .order(id: :asc)
                           .with(:addresses, :passport).to_a

          res.size.should eq(2)

          res[0].addresses.size.should eq(2)
          res[1].addresses.size.should eq(0)
          res[0].passport.should be_nil
        end
      end

      context "retrieving several relation from same table" do
        it "uses auto aliasing" do
          c1 = Factory.create_contact(name: "a")
          c2 = Factory.create_contact(name: "b")

          a1 = Factory.create_address(main: false, contact_id: c1.id)
          a2 = Factory.create_address(main: false, contact_id: c1.id)
          a3 = Factory.create_address(main: true, contact_id: c1.id)

          q = Contact.all.eager_load(:addresses, :main_address)
          r = q.to_a
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
        match_array(res[0].addresses.map(&.id), [a1.id])
        match_array(res[1].addresses.map(&.id), [a2.id])
        match_array(res[1].facebook_profiles.map(&.id), [f.id])

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
  end

  describe "#includes" do
    context "with nested relation defined as symbol" do
      it do
        c = Factory.create_contact(name: "contact 1")
        Factory.create_address(contact_id: c.id, street: "some st.")
        country = Factory.create_country
        Factory.create_city(country_id: country.id)
        c.add_countries(country)

        res = Contact.all.includes(:addresses, :passport, countries: :cities).to_a
        expect_query_silence do
          res.size.should eq(1)
          res[0].addresses.size.should eq(1)
          res[0].passport.should be_nil
          res[0].countries.size.should eq(1)
          res[0].countries[0].cities.size.should eq(1)
        end
      end
    end

    context "with nested relation defined as array" do
      it do
        c = Factory.create_contact(name: "contact 1")
        Factory.create_address(contact_id: c.id, street: "some st.")
        country = Factory.create_country
        Factory.create_city(country_id: country.id)
        c.add_countries(country)

        res = Contact.all.includes(:addresses, :passport, countries: [:cities]).to_a
        expect_query_silence do
          res.size.should eq(1)
          res[0].addresses.size.should eq(1)
          res[0].passport.should be_nil
          res[0].countries.size.should eq(1)
          res[0].countries[0].cities.size.should eq(1)
        end
      end
    end

    context "with nested relation defined as hash" do
      it do
        c = Factory.create_contact(name: "contact 1")
        Factory.create_address(contact_id: c.id, street: "some st.")
        country = Factory.create_country
        Factory.create_city(country_id: country.id)
        c.add_countries(country)

        res = City.all.includes(country: {:contacts => [:addresses, :passport]}).to_a
        expect_query_silence do
          res.size.should eq(1)
          res[0].country!.contacts.size.should eq(1)
          res[0].country!.contacts[0].addresses.size.should eq(1)
          res[0].country!.contacts[0].passport.should be_nil
        end
      end
    end

    it "doesn't add JOIN condition" do
      Contact.all.includes(:addresses)._joins.nil?.should be_true
    end

    it "stops reloading relation from db if there is no records" do
      Factory.create_contact
      c = Contact.all.includes(:addresses).to_a
      expect_query_silence do
        c[0].addresses
      end
    end

    it "stop reloading relation from the db if it is already loaded" do
      c = Factory.create_contact
      Factory.create_address(contact_id: c.id)
      c = Contact.all.includes(:addresses).to_a
      expect_query_silence do
        c[0].addresses.size.should eq(1)
      end
    end

    context "with defined inverse_of" do
      it "sets owner during building collection" do
        c = Factory.create_contact
        a = Factory.create_address(contact_id: c.id)
        res = Contact.all.includes(:addresses).to_a
        expect_query_silence do
          res[0].addresses[0].contact
        end
      end

      it "sets all deep relations" do
        c = Factory.create_contact(name: "contact 1")
        Factory.create_address(contact_id: c.id, street: "some st.")
        country = Factory.create_country
        Factory.create_city(country_id: country.id)
        c.add_countries(country)

        res = City.all.includes(country: {:contacts => [:addresses]}).to_a
        expect_query_silence do
          res.size.should eq(1)
          res[0].country!.contacts[0].addresses[0].contact
        end
      end
    end

    describe "one-to-many relation" do
      it do
        c = Factory.create_contact
        Factory.create_address(contact_id: c.id)
        Factory.create_address(contact_id: c.id)
        executed_times = 0
        Address.all.includes(:contact).to_a.each do |address|
          executed_times += 1
          address.contact.should_not be_nil
        end
        executed_times.should eq(2)
      end
    end
  end

  describe "#preload" do
    # NOTE: #preload is an alias for #includes so just check if it delegates call to original method
    context "with nested relation defined as array" do
      it do
        c = Factory.create_contact(name: "contact 1")
        Factory.create_address(contact_id: c.id, street: "some st.")
        country = Factory.create_country
        Factory.create_city(country_id: country.id)
        c.add_countries(country)

        res = Contact.all.includes(:addresses, :passport, countries: [:cities]).to_a
        expect_query_silence do
          res.size.should eq(1)
          res[0].addresses.size.should eq(1)
          res[0].passport.should be_nil
          res[0].countries.size.should eq(1)
          res[0].countries[0].cities.size.should eq(1)
        end
      end
    end
  end

  describe "#_select_fields" do
    context "query has no specified select fields" do
      context "has eager loaded relations" do
        subject = Contact.all.eager_load(:addresses)._select_fields

        it "includes own star criteria" do
          subject.any? { |e| e.table == "contacts" && e.field == "*" }.should be_true
        end

        it "includes all mentioned relation star criterias" do
          subject.any? { |e| e.table == "addresses" && e.field == "*" }.should be_true
        end
      end

      it "returns only own star riteria" do
        fields = Contact.all._select_fields
        fields.size.should eq(1)

        fields[0].is_a?(Jennifer::QueryBuilder::Star).should be_true
        fields[0].table.should eq("contacts")
      end
    end

    context "query has specified fields" do
      it "returns specified fields" do
        fields = Contact.all.select { [_id, _age] }._select_fields
        fields.size.should eq(2)
        fields[0].field.should eq("id")
        fields[1].field.should eq("age")
      end
    end
  end

  describe "#find_by_sql" do
    query = <<-SQL
      SELECT contacts.*
      FROM contacts
    SQL

    it "builds all requested objects" do
      Factory.create_contact
      res = Contact.all.find_by_sql(query)
      res.size.should eq(1)
      res[0].id.nil?.should be_false
    end

    it "raises exception if not all required fields are listed in the select clause" do
      Factory.create_contact
      _query = <<-SQL
        SELECT id
        FROM contacts
      SQL
      expect_raises(Jennifer::BaseException, /includes only/) do
        res = Contact.all.find_by_sql(_query)
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
  end

  describe "#find_each" do
    it "loads each in batches without specifying primary key" do
      ids = Factory.create_contact(3).map(&.id)
      yield_count = 0
      buff = [] of Int32
      Contact.all.find_each(2, ids[1]) do |record|
        buff << record.id!
      end
      buff.should eq(ids[1..2])
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
      clone._order.empty?.should be_true
    end

    it "excludes join if given" do
      q = Contact.all.join("passports") { _contact_id == _contacts__id }
      clone = q.except(["join"])
      clone._joins.nil?.should be_true
    end

    it "excludes join if given" do
      q = Contact.all.union(Query["contacts"])
      clone = q.except(["union"])
      clone._unions.nil?.should be_true
    end

    it "excludes group if given" do
      q = Contact.all.group(:age)
      clone = q.except(["group"])
      clone._groups.empty?.should be_true
    end

    it "excludes muting if given" do
      q = Contact.all.join("passports") { _contact_id == _contacts__id }
      clone = q.except(["none"])
      clone.eql?(q).should be_true
    end

    it "excludes select if given" do
      q = Contact.all.select { [_id] }
      clone = q.except(["select"])
      clone._select_fields.size.should eq(1)
      clone._select_fields[0].should be_a(Jennifer::QueryBuilder::Star)
    end

    it "excludes where if given" do
      q = Contact.where { _age < 99 }
      clone = q.except(["where"])
      clone.to_sql.should_not match(/WHERE/)
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

    it { clone.to_sql.should match(/WHERE/) }
    it { clone.to_sql.should match(/GROUP/) }
    it { clone.to_sql.should match(/ORDER/) }
    it { clone.to_sql.should match(/JOIN/) }
    it { clone.to_sql.should match(/UNION/) }
    it { clone._select_fields[0].should_not be_a(Jennifer::QueryBuilder::Star) }
    it { clone.with_relation?.should be_true }
    pending "add more precise testing" {}
  end

  context "complex query example" do
    postgres_only do
      it "allows custom select with grouping" do
        Factory.create_contact
        Contact
          .all
          .select { [sql("count(*)").alias("stat_count"), sql("date_trunc('year', created_at)").alias("period")] }
          .group("period")
          .order({"period" => :desc})
          .results.size.should eq(1)
      end

      it "allows to use float for filtering decimal fields" do
        converter = Jennifer::Model::ParameterConverter.new
        c = Factory.create_contact
        c.ballance = converter.parse("15.1", "Numeric").as(PG::Numeric)
        c.save
        Contact.all.where { _ballance == 15.1 }.count.should eq(1)
      end
    end
  end
end
