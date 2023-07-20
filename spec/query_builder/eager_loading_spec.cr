require "../spec_helper"

# TODO: add checking for log entries when we shouldn't hit db

describe Jennifer::QueryBuilder::EagerLoading do
  describe "#with_relation" do
    it "adds to select clause given relation" do
      q1 = Contact.all.relation(:addresses)
      q1.with_relation(:addresses)
      select_clause(q1).should match(/SELECT #{reg_quote_identifier("contacts")}\.\*, #{reg_quote_identifier("addresses")}\.\*/)
    end

    it "raises error if given relation is not exists" do
      q1 = Contact.all
      expect_raises(Jennifer::UnknownRelation, "Unknown relation for Contact: relation") do
        q1.relation(:addresses).with_relation(:relation)
        select_clause(q1)
      end
    end

    it "raises error if given relation is not joined" do
      expect_raises(Jennifer::BaseException, /with_relation should be called after corresponding join/) do
        select_clause(Contact.all.with_relation(:addresses))
      end
    end
  end

  describe "#eager_load" do
    it "allows to specify nested relation as a named tuple Symbol => Symbol alongside other top level argument" do
      c = Factory.create_contact(name: "contact 1")
      Factory.create_address(contact_id: c.id, street: "some st.")
      country = Factory.create_country
      Factory.create_city(country_id: country.id)
      c.add_countries(country)

      res = Contact.all.eager_load(:addresses, :passport, countries: :cities).to_a
      expect_query_silence do
        res.size.should eq(1)
        res[0].addresses.size.should eq(1)
        res[0].passport.should be_nil # NOTE: passport doesn't exist and this doesn't breaks other loading
        res[0].countries.size.should eq(1)
        res[0].countries[0].cities.size.should eq(1)
      end
    end

    it "allows to specify nested relation as a named tuple Symbol => Array(Symbol) alongside other top level argument" do
      c = Factory.create_contact(name: "contact 1")
      Factory.create_address(contact_id: c.id, street: "some st.")
      country = Factory.create_country
      Factory.create_city(country_id: country.id)
      c.add_countries(country)

      res = Contact.all.eager_load(:addresses, :passport, countries: [:cities]).to_a
      expect_query_silence do
        res.size.should eq(1)
        res[0].addresses.size.should eq(1)
        res[0].passport.should be_nil # NOTE: passport doesn't exist and this doesn't breaks other loading
        res[0].countries.size.should eq(1)
        res[0].countries[0].cities.size.should eq(1)
      end
    end

    it "allows to specify nested relation as a named tuple Symbol => Hash(String, Array(Symbol))" do
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

    it "properly loads several relations from the same table" do
      c = Factory.create_contact
      Factory.create_address(contact_id: c.id, main: false)
      main_address = Factory.create_address(contact_id: c.id, main: true)
      res = Contact.all.eager_load(:addresses, :main_address).to_a
      expect_query_silence do
        res[0].addresses.size.should eq(2)
        res[0].main_address!.id.should eq(main_address.id)
      end
    end

    it "stops reloading relation from db if there is no records" do
      Factory.create_contact
      c = Contact.all.eager_load(:addresses).to_a
      expect_query_silence do
        c[0].addresses.should be_empty
      end
    end

    context "when record in specified relation chain doesn't exist" do
      it do
        country = Factory.create_country
        Factory.create_city(country_id: country.id)

        res = City.all.eager_load(country: {:contacts => [:addresses]}).to_a
        expect_query_silence do
          res.size.should eq(1)
          res[0].country!.contacts.should be_empty
        end
      end
    end

    context "when relation is defined with inverse_of option" do
      it "loads relation as well" do
        c1 = Factory.create_contact(name: "asd")
        Factory.create_address(contact_id: c1.id, street: "asd st.")

        res = Contact.all.eager_load(:addresses).first!
        expect_query_silence do
          res.addresses[0].street.should eq("asd st.")
        end
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

    context "when target class defines not all fields and has non strict mapping" do
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
      it "respects additional request specified for a relation" do
        contact = Factory.create_contact
        Factory.create_address(contact_id: contact.id)
        main_address = Factory.create_address(contact_id: contact.id, main: true)
        Contact.all.eager_load(:main_address).first!.main_address!.id.should eq(main_address.id)
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
      Contact.all.includes(:addresses)._joins?.should be_falsey
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

    it "loads STI record" do
      c = ContactWithDependencies.create!({name: "test name", description: "description"})
      profile1 = Factory.create_facebook_profile(contact_id: c.id)
      profile2 = Factory.create_twitter_profile(contact_id: c.id)
      ContactWithDependencies.eager_load(:profiles).order(Profile._id.asc).each do |contact|
        contact.id.should eq(c.id)
        contact.profiles.size.should eq(2)
        contact.profiles[0].should be_a(FacebookProfile)
        contact.profiles[0].as(FacebookProfile).uid.should eq(profile1.uid)

        contact.profiles[1].should be_a(TwitterProfile)
        contact.profiles[1].as(TwitterProfile).email.should eq(profile2.email)
      end
    end

    context "with defined inverse_of" do
      it "sets owner during building collection" do
        c = Factory.create_contact
        Factory.create_address(contact_id: c.id)
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

    describe "JSON" do
      it do
        u = Factory.create_user([:with_valid_password])
        value = {:a => 2}.to_json
        AllTypeModel.create!({:bigint_f => u.id, :json_f => value})
        executed_times = 0
        User.all.preload(:all_types_records).to_a.each do |user|
          executed_times += 1
          expect_query_silence do
            user.all_types_records[0].json_f.should eq(JSON.parse(value))
          end
        end
        executed_times.should eq(1)
      end
    end

    postgres_only do
      describe "Array(Int32)" do
        it do
          u = Factory.create_user([:with_valid_password])
          value = [1, 2]
          AllTypeModel.create!({:bigint_f => u.id, :array_int32_f => value})
          executed_times = 0
          User.all.preload(:all_types_records).to_a.each do |user|
            executed_times += 1
            expect_query_silence do
              user.all_types_records[0].array_int32_f.should eq(value)
            end
          end
          executed_times.should eq(1)
        end
      end

      describe "Array(String)" do
        it do
          u = Factory.create_user([:with_valid_password])
          value = %w[foo bar]
          AllTypeModel.create!({:bigint_f => u.id, :array_string_f => value})
          executed_times = 0
          User.all.preload(:all_types_records).to_a.each do |user|
            executed_times += 1
            expect_query_silence do
              user.all_types_records[0].array_string_f.should eq(value)
            end
          end
          executed_times.should eq(1)
        end
      end

      describe "Array(Time)" do
        it do
          u = Factory.create_user([:with_valid_password])
          value = [
            Time.local(2010, 12, 10, 20, 10, 10, location: ::Jennifer::Config.local_time_zone),
            Time.local(2011, 12, 10, 20, 10, 10, location: ::Jennifer::Config.local_time_zone),
          ]
          AllTypeModel.create!({:bigint_f => u.id, :array_time_f => value})
          executed_times = 0
          User.all.preload(:all_types_records).to_a.each do |user|
            executed_times += 1
            expect_query_silence do
              user.all_types_records[0].array_time_f.should eq(value)
            end
          end
          executed_times.should eq(1)
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
        fields.map(&.field).should eq(%w(id age))
      end
    end
  end
end
