require "../spec_helper"

# TODO: add checking for log entries when we shouldn't hit db

describe Jennifer::QueryBuilder::EagerLoading do
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
end
