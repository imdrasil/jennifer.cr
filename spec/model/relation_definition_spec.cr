require "../spec_helper"

describe Jennifer::Model::RelationDefinition do
  describe "%nullify_dependecy" do
    it "adds before_desctroy callback" do
      ContactWithDependencies::BEFORE_DESTROY_CALLBACKS.includes?("__nullify_callback_facebook_profiles").should be_true
    end

    it "doen't invoke callbacks on associated model" do
      c = Factory.create_contact
      Factory.create_facebook_profile(contact_id: c.id)
      c = ContactWithDependencies.all.last!
      c.facebook_profiles.size.should eq(1)
      c.destroy
      f = FacebookProfile.all.last!
      f.contact_id.nil?.should be_true
    end
  end

  describe "%delete_dependency" do
    it "adds before_desctroy callback" do
      ContactWithDependencies::BEFORE_DESTROY_CALLBACKS.includes?("__delete_callback_addresses").should be_true
    end

    it "doen't invoke callbacks on associated model" do
      c = Factory.create_contact
      Factory.create_address(contact_id: c.id)
      count = Address.destroy_counter
      c = ContactWithDependencies.all.last!
      c.addresses.size.should eq(1)
      c.destroy
      Address.all.exists?.should be_false
      Address.destroy_counter.should eq(count)
    end
  end

  describe "%destroy_dependency" do
    it "adds before_desctroy callback" do
      ContactWithDependencies::BEFORE_DESTROY_CALLBACKS.includes?("__destroy_callback_passports").should be_true
    end

    it "invokes callbacks on associated model" do
      c = Factory.create_contact
      Factory.create_passport(contact_id: c.id)
      count = Passport.destroy_counter
      c = ContactWithDependencies.all.last!
      c.passports.size.should eq(1)
      c.destroy
      Passport.all.exists?.should be_false
      Passport.destroy_counter.should eq(count + 1)
    end
  end

  describe "%restrict_with_exception_dependency" do
    it "adds before_desctroy callback" do
      ContactWithDependencies::BEFORE_DESTROY_CALLBACKS.includes?("__restrict_with_exception_callback_twitter_profiles").should be_true
    end

    it "raises exception if any associated record exists" do
      c = Factory.create_contact
      Factory.create_twitter_profile(contact_id: c.id)
      c = ContactWithDependencies.all.last!
      c.twitter_profiles.size.should eq(1)
      expect_raises(::Jennifer::RecordExists) do
        c.destroy
      end
      TwitterProfile.all.count.should eq(1)
    end
  end

  describe "%has_many" do
    it "adds relation name to RELATION_NAMES constant" do
      Contact::RELATION_NAMES.size.should eq(6)
      Contact::RELATION_NAMES[0].should eq("addresses")
    end

    context "query" do
      it "sets correct query part" do
        Contact.relation("addresses").condition_clause.as_sql.should eq("addresses.contact_id = contacts.id")
      end

      context "when declaration has additional block" do
        it "sets correct query part" do
          Contact.relation("main_address").condition_clause.as_sql.should match(/addresses\.contact_id = contacts\.id AND addresses\.main/)
        end
      end
    end

    describe "#/relation_name/_query" do
      it "returns query object" do
        c = Factory.create_contact
        q = c.addresses_query
        q.as_sql.should match(/addresses.contact_id = %s/)
        q.sql_args.should eq(db_array(c.id))
      end

      context "relation is a sti subclass" do
        it "returns proper objects" do
          c = Factory.build_contact
          q = c.facebook_profiles_query
          q.as_sql.should match(/profiles\.type = %s/)
          q.sql_args.includes?("FacebookProfile").should be_true
        end
      end
    end

    describe "#/relation_name/" do
      it "loads relation objects from db" do
        c = Factory.create_contact
        Factory.create_address(contact_id: c.id)
        c.addresses.size.should eq(1)
      end

      it "will not hit db again if previous call returns empty array" do
        c = Factory.create_contact
        count = query_count
        c.addresses.empty?.should be_true
        query_count.should eq(count + 1)
        c.addresses
        query_count.should eq(count + 1)
      end
    end

    describe "#add_/relation_name/" do
      it "creates new objects depending on given hash" do
        c = Factory.create_contact
        c.add_addresses({:main => true, :street => "some street", :details => nil})
        c.addresses.size.should eq(1)
        c.addresses[0].street.should eq("some street")
        c.addresses[0].contact_id.should eq(c.id)
        c.addresses[0].new_record?.should be_false
      end

      it "creates new objects depending on given object" do
        c = Factory.create_contact
        a = Factory.build_address(street: "some street")
        c.add_addresses(a)
        c.addresses.size.should eq(1)
        c.addresses[0].street.should eq("some street")
        c.addresses[0].contact_id.should eq(c.id)
        c.addresses[0].new_record?.should be_false
      end

      it "stop loading relation from db" do
        c = Factory.create_contact
        a = Factory.build_address(street: "some street")
        Factory.create_address(contact_id: c.id)
        c.add_addresses(a)
        count = query_count
        c.addresses.size.should eq(1)
        query_count.should eq(count)
      end
    end

    describe "#remove_/relation_name/" do
      it "removes foreign key and removes it from array" do
        c = Factory.create_contact
        a = Factory.build_address(street: "some street")
        c.add_addresses(a)
        c.addresses[0].new_record?.should be_false
        c.remove_addresses(a)
        c.addresses.size.should eq(0)
        a = Address.find!(a.id)
        a.contact_id.should be_nil
      end
    end

    describe "#/relation_name/_reload" do
      it "reloads objects" do
        c = Factory.create_contact
        a = Factory.create_address(contact_id: c.id)
        c.addresses
        a.street = "some strange street"
        a.save
        c.addresses_reload
        c.addresses[0].street.should eq("some strange street")
      end
    end
  end

  describe "%belongs_to" do
    it "adds relation name to RELATION_NAMES constant" do
      Address::RELATION_NAMES.size.should eq(1)
      Address::RELATION_NAMES[0].should eq("contact")
    end

    context "query" do
      it "sets correct query part" do
        Address.relation("contact").condition_clause.as_sql.should eq("contacts.id = addresses.contact_id")
      end

      pending "when desclaration has additional block" do
        it "sets correct query part" do
          Address.relation("main_address").condition_clause.as_sql.should match(/addresses\.contact_id = contacts\.id AND addresses\.main/)
        end
      end
    end

    describe "#/relation_name/_query" do
      it "returns query object" do
        a = Factory.create_address(contact_id: 1)
        q = a.contact_query
        q.as_sql.should match(/contacts.id = %s/)
        q.sql_args.should eq(db_array(a.contact_id))
      end
    end

    describe "#/relation_name/" do
      it "loads relation objects from db" do
        c = Factory.create_contact
        a = Factory.create_address(contact_id: c.id)
        a.contact.should be_a(Contact)
      end

      it "will not hit db again if previous call returns empty array" do
        a = Factory.create_address
        count = query_count
        a.contact.nil?.should be_true
        query_count.should eq(count + 1)
        a.contact
        query_count.should eq(count + 1)
      end
    end

    describe "#add_/relation_name/" do
      it "builds new objects depending on given hash" do
        a = Factory.create_address
        a.add_contact({:name => "some name", :age => 16})
        a.contact!.name.should eq("some name")
      end
    end

    describe "#/relation_name/_reload" do
      it "reloads objects" do
        c = Factory.create_contact
        a = Factory.create_address(contact_id: c.id)
        a.contact
        c.name = "some new name"
        c.save
        a.contact_reload
        a.contact_reload.not_nil!.name.should eq("some new name")
      end
    end

    describe "#remove_/relation_name/" do
      it "removes foreign key and removes it from array" do
        c = Factory.create_contact
        a = Factory.create_address(contact_id: c.id)
        a.contact
        a.remove_contact
        a.contact.should be_nil
        Address.find!(a.id).contact_id.should be_nil
      end
    end
  end

  describe "%has_one" do
    it "adds relation name to RELATION_NAMES constant" do
      Contact::RELATION_NAMES[0].should eq("addresses")
    end

    context "query" do
      it "sets correct query part" do
        Contact.relation("passport").condition_clause.as_sql.should eq("passports.contact_id = contacts.id")
      end

      context "when desclaration has additional block" do
        it "sets correct query part" do
          sql_reg = /addresses\.contact_id = contacts\.id AND addresses\.main/
          Contact.relation("main_address").condition_clause.as_sql.should match(sql_reg)
        end
      end
    end

    describe "#/relation_name/_query" do
      it "returns query object" do
        c = Factory.create_contact
        q = c.main_address_query
        q.as_sql.should match(/addresses.contact_id = %s AND addresses.main/)
        q.sql_args.should eq(db_array(c.id))
      end
    end

    describe "#/relation_name/" do
      it "loads relation objects from db" do
        c = Factory.create_contact
        Factory.create_address(contact_id: c.id, main: true)
        c.main_address.nil?.should be_false
      end

      it "will not hit db again if previous call returns empty array" do
        c = Factory.create_contact
        count = query_count
        c.main_address.nil?.should be_true
        query_count.should eq(count + 1)
        c.main_address
        query_count.should eq(count + 1)
      end
    end

    describe "#add_/relation_name/" do
      it "builds new objects depending on given hash" do
        c = Factory.build_contact
        c.add_main_address({:main => true, :street => "some street", :contact_id => 1, :details => nil})
        c.main_address.nil?.should be_false
      end
    end

    describe "#/relation_name/_reload" do
      it "reloads objects" do
        c = Factory.create_contact
        a = Factory.create_address(contact_id: c.id, main: true)
        c.main_address
        a.street = "some strange street"
        a.save
        c.main_address_reload
        c.main_address!.street.should eq("some strange street")
      end
    end

    describe "#remove_/relation_name/" do
      it "removes foreign key and removes it from array" do
        c = Factory.create_contact
        p = Factory.create_passport(contact_id: c.id)
        c.passport
        c.remove_passport
        c.passport.should be_nil
        Passport.find!(p.enn).contact_id.should be_nil
      end
    end
  end

  describe "%has_and_belongs_many" do
    context "query" do
      pending "sets correct query part" do
        Contact.relation("countries").condition_clause.as_sql.should eq("addresses.contact_id = contacts.id")
      end
    end

    describe "#/relation_name/_query" do
      it "returns query object" do
        c = Factory.create_contact
        q = c.countries_query
        select_query(q)
          .should match(/JOIN contacts_countries ON \(contacts_countries\.country_id = countries\.id AND contacts_countries\.contact_id = %s\)/)
        q.select_args.should eq(db_array(c.id))
      end

      context "relation is a sti subclass" do
        it "returns proper objects" do
          c = Factory.create_contact
          q = c.facebook_many_profiles_query
          select_query(q)
            .should match(/JOIN contacts_profiles ON \(contacts_profiles\.profile_id = profiles\.id AND contacts_profiles\.contact_id = %s\)/)
          select_query(q)
            .should match(/profiles\.type = %s/)
          q.select_args.includes?("FacebookProfile").should be_true
        end

        it "works as well in inverse direction" do
          c = Factory.create_facebook_profile
          q = c.facebook_contacts_query
          select_query(q)
            .should match(/JOIN contacts_profiles ON \(contacts_profiles\.contact_id = contacts\.id AND contacts_profiles\.profile_id = %s\)/)
          q.select_args.should eq(db_array(c.id))
        end
      end
    end

    describe "#/relation_name/" do
      it "loads relation objects from db" do
        c = Factory.create_contact

        c.add_countries({:name => "k1"})
        c.countries.size.should eq(1)
        Country.all.first!.name.should eq("k1")
      end

      it "will not hit db again if previous call returns empty array" do
        c = Factory.create_contact
        count = query_count
        c.countries.empty?.should be_true
        query_count.should eq(count + 1)
        c.countries
        query_count.should eq(count + 1)
      end
    end

    describe "#add_/relation_name/" do
      it "builds new objects depending on given hash" do
        c = Factory.create_contact
        c.add_countries({:name => "k1"})
        c.countries.size.should eq(1)
        Country.all.count.should eq(1)
        ::Jennifer::Query.new("contacts_countries").where do
          (_contact_id == c.id) & (_country_id == c.countries[0].id)
        end.exists?.should be_true
        c.countries[0].name.should eq("k1")
      end
    end

    describe "#remove_/relation_name/" do
      it "removes join table record from db and array" do
        c = Factory.create_contact
        country = Factory.create_country
        c.add_countries(country)
        c.countries.size.should eq(1)
        c.remove_countries(country)
        c.countries.size.should eq(0)
        ::Jennifer::Query.new("contacts_countries").where do
          (_contact_id == c.id) & (_country_id == country.id)
        end.exists?.should be_false
      end
    end

    describe "#/relation_name/_reload" do
      it "reloads objects" do
        c = Factory.create_contact
        c.add_countries({:name => "k1"})
        country = Country.all.first!
        country.name = "k2"
        country.save
        c.countries_reload
        c.countries[0].name.should eq("k2")
      end
    end

    describe "#__/relation_name/_clean" do
      it "removes join table record" do
        c = Factory.create_contact
        country = Factory.create_country
        c.add_countries(country)
        q = Jennifer::Query.new("contacts_countries").where do
          (_contact_id == c.id) & (_country_id == country.id)
        end
        q.exists?.should be_true
        country.__contacts_clean
        q.exists?.should be_false
      end
    end
  end
end
