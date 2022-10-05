require "../spec_helper"

module Jennifer::Model
  class NoteWithDestroyDependency < Base
    include Note::Mapping

    self.table_name "notes"

    belongs_to :notable, Union(User | FacebookProfile), dependent: :destroy, polymorphic: true
    actual_table_field_count
  end

  class NoteWithExceptionDependency < Base
    include Note::Mapping

    self.table_name "notes"

    belongs_to :notable, Union(User | FacebookProfile), dependent: :restrict_with_exception, polymorphic: true
    actual_table_field_count
  end

  class FacebookProfileWithNullifyNotable < Base
    include ::FacebookProfileWithDestroyNotable::Mapping

    self.table_name "profiles"

    has_many :notes, NoteWithCallback, inverse_of: :notable, polymorphic: true, dependent: :nullify
    actual_table_field_count
  end

  class NoteWithRequiredDependency < Base
    include Note::Mapping

    self.table_name "notes"

    belongs_to :notable, Union(User | FacebookProfile), dependent: :destroy, polymorphic: true, required: true
    actual_table_field_count
  end

  class NoteWithRequiredDependencyProcMessage < Base
    include Note::Mapping

    self.table_name "notes"

    belongs_to :notable,
      Union(User | FacebookProfile),
      dependent: :destroy,
      polymorphic: true,
      required: ->(_record : Jennifer::Model::Translation, _field : String) { "notable is missing" }
    actual_table_field_count
  end

  describe RelationDefinition do
    describe "%nullify_dependency" do
      it "adds before_destroy callback" do
        ContactWithDependencies::CALLBACKS[:destroy][:before].includes?("__nullify_callback_facebook_profiles").should be_true
      end

      it "doesn't invoke callbacks on associated model" do
        c = Factory.create_contact
        Factory.create_facebook_profile(contact_id: c.id)
        c = ContactWithDependencies.all.last!
        c.facebook_profiles.size.should eq(1)
        c.destroy
        f = FacebookProfile.all.last!
        f.contact_id.nil?.should be_true
      end

      describe "polymorphic" do
        describe "has_many" do
          it "doesn't invoke callbacks on associated model" do
            p = FacebookProfileWithNullifyNotable.find!(Factory.create_facebook_profile(type: "Jennifer::Model::FacebookProfileWithNullifyNotable").id)
            note = NoteWithCallback.find!(Factory.create_note.id)
            p.add_notes(note)
            count = NoteWithCallback.destroy_counter
            p.destroy
            note.reload
            note.notable_id.should be_nil
            note.notable_type.should be_nil
            NoteWithCallback.destroy_counter.should eq(count)
          end
        end
      end
    end

    describe "%delete_dependency" do
      it "adds before_destroy callback" do
        ContactWithDependencies::CALLBACKS[:destroy][:before].includes?("__delete_callback_addresses").should be_true
      end

      it "doesn't invoke callbacks on associated model" do
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
      it "adds before_destroy callback" do
        ContactWithDependencies::CALLBACKS[:destroy][:before].includes?("__destroy_callback_passports").should be_true
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

      describe "polymorphic relation" do
        describe "belongs_to" do
          it "adds before_destroy callback" do
            NoteWithDestroyDependency::CALLBACKS[:destroy][:before].includes?("__destroy_callback_notable").should be_true
          end

          it "invokes callbacks on associated model" do
            n = NoteWithDestroyDependency.find!(Factory.create_note.id)
            n.add_notable(Factory.create_facebook_profile)
            count = FacebookProfile.destroy_counter
            n.destroy
            FacebookProfile.all.exists?.should be_false
            FacebookProfile.destroy_counter.should eq(count + 1)
          end
        end

        describe "has_many" do
          it "adds before_destroy callback" do
            FacebookProfileWithDestroyNotable::CALLBACKS[:destroy][:before].includes?("__destroy_callback_notes").should be_true
          end

          it "invokes callbacks on associated model" do
            fp = Factory.create_facebook_profile(type: "Jennifer::Model::FacebookProfileWithDestroyNotable")
            p = FacebookProfileWithDestroyNotable.find!(fp.id)
            p.add_notes(NoteWithCallback.find!(Factory.create_note.id))
            count = NoteWithCallback.destroy_counter
            p.destroy
            NoteWithCallback.all.exists?.should be_false
            NoteWithCallback.destroy_counter.should eq(count + 1)
          end
        end
      end
    end

    describe "%restrict_with_exception_dependency" do
      it "adds before_destroy callback" do
        ContactWithDependencies::CALLBACKS[:destroy][:before].includes?("__restrict_with_exception_callback_twitter_profiles").should be_true
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

      it "passes if no associated object exists" do
        c = Factory.create_contact
        c.destroy
      end

      describe "polymorphic relation" do
        describe "belongs_to" do
          it "adds before_destroy callback" do
            NoteWithExceptionDependency::CALLBACKS[:destroy][:before].includes?("__restrict_with_exception_callback_notable").should be_true
          end

          it "raises exception if any associated record exists" do
            n = NoteWithExceptionDependency.find!(Factory.create_note.id)
            n.add_notable(Factory.create_facebook_profile)
            expect_raises(::Jennifer::RecordExists) do
              n.destroy
            end
            FacebookProfile.all.count.should eq(1)
          end

          it "passes if no associated object exists" do
            n = NoteWithExceptionDependency.find!(Factory.create_note.id)
            n.destroy
          end
        end
      end
    end

    describe "%has_many" do
      it "adds relation name to RELATIONS constant" do
        Contact::RELATIONS.size.should eq(7)
        Contact::RELATIONS.has_key?("addresses").should be_true
      end

      context "query" do
        it "sets correct query part" do
          Contact.relation("addresses").as(Jennifer::Relation::HasMany).condition_clause.as_sql
            .should eq(%(#{quote_identifier("addresses.contact_id")} = #{quote_identifier("contacts.id")}))
        end
      end

      describe "#/relation_name/_query" do
        it "returns query object" do
          c = Factory.create_contact
          q = c.addresses_query
          q.as_sql.should match(/#{reg_quote_identifier("addresses.contact_id")} = %s/)
          q.sql_args.should eq(db_array(c.id))
        end

        context "relation is a sti subclass" do
          it "returns proper objects" do
            c = Factory.build_contact
            q = c.facebook_profiles_query
            q.as_sql.should match(/#{reg_quote_identifier("profiles.type")} = %s/)
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

        context "with defined inverse_of" do
          it "sets owner during building collection" do
            c = Factory.create_contact
            Factory.create_address(contact_id: c.id)
            count = query_count
            c.addresses[0].contact
            query_count.should eq(count + 1)
          end

          it "sets owner during building collection 2" do
            c = Factory.create_contact
            Factory.create_facebook_profile(contact_id: c.id)
            count = query_count
            c.facebook_profiles[0].contact
            query_count.should eq(count + 1)
          end
        end

        context "new record" do
          it "doesn't hit the db" do
            c = Factory.build_contact
            count = query_count
            c.addresses
            query_count.should eq(count)
          end
        end
      end

      describe "#add_/relation_name/" do
        it "creates new objects depending on given hash" do
          c = Factory.create_contact
          c.addresses.size.should eq(0)

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

      describe "polymorphic" do
        relation = FacebookProfileWithDestroyNotable.relation("notes").as(Jennifer::Relation::PolymorphicHasMany)

        describe "query" do
          it "sets correct query part" do
            relation.condition_clause.as_sql
              .should eq("#{quote_identifier("notes.notable_id")} = #{quote_identifier("profiles.id")} AND #{quote_identifier("notes.notable_type")} = %s")
            relation.condition_clause.sql_args.should eq(db_array("FacebookProfileWithDestroyNotable"))
          end
        end

        describe "#/relation_name/_query" do
          it "returns query object" do
            p = FacebookProfileWithDestroyNotable.find!(Factory.create_facebook_profile(type: "FacebookProfileWithDestroyNotable").id)
            q = p.notes_query
            q.as_sql.should match(/#{reg_quote_identifier("notes.notable_id")} = %s AND #{reg_quote_identifier("notes.notable_type")} = %s/)
            q.sql_args.should eq(db_array(p.id, "FacebookProfileWithDestroyNotable"))
          end
        end

        describe "#/relation_name/" do
          it "loads relation objects from db" do
            p = FacebookProfileWithDestroyNotable.find!(Factory.create_facebook_profile(type: "FacebookProfileWithDestroyNotable").id)
            n = Factory.create_note(notable_id: p.id, notable_type: "FacebookProfileWithDestroyNotable")
            p.notes.size.should eq(1)
            p.notes[0].id.should eq(n.id)
          end
        end
      end
    end

    describe "%belongs_to" do
      it "adds relation name to RELATIONS constant" do
        Address::RELATIONS.size.should eq(1)
        Address::RELATIONS.has_key?("contact").should be_true
      end

      describe "query" do
        it "sets correct query part" do
          Address.relation("contact").as(Jennifer::Relation::BelongsTo).condition_clause.as_sql
            .should eq(%(#{quote_identifier("contacts.id")} = #{quote_identifier("addresses.contact_id")}))
        end

        context "when declaration has additional block" do
          it "sets correct query part" do
            query = JohnPassport.relation("contact").as(Jennifer::Relation::BelongsTo).condition_clause
            query.as_sql
              .should match(/#{reg_quote_identifier("contacts.id")} = #{reg_quote_identifier("passports.contact_id")} AND #{reg_quote_identifier("contacts.name")} = %s/)
            query.sql_args.should eq(db_array("John"))
          end
        end
      end

      describe "#/relation_name/_query" do
        it "returns query object" do
          c = Factory.create_contact
          a = Factory.create_address(contact_id: c.id)
          q = a.contact_query
          q.as_sql.should match(/#{reg_quote_identifier("contacts.id")} = %s/)
          q.sql_args.should eq(db_array(c.id))
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

        context "new record" do
          it "doesn't hit the db" do
            c = Factory.build_contact
            count = query_count
            c.addresses
            query_count.should eq(count)
          end
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

      describe "polymorphic" do
        it "adds relation name to RELATIONS constant" do
          Note::RELATIONS.size.should eq(1)
          Note::RELATIONS.has_key?("notable").should be_true
        end

        describe "#/relation_name/_query" do
          it "returns query object" do
            n = Factory.create_note([:with_user])
            q = n.notable_query
            q.as_sql.should match(/#{reg_quote_identifier("users.id")} = %s/)
            q.sql_args.should eq(db_array(n.notable!.id, "%on"))
          end
        end

        describe "#/relation_name/" do
          it "loads relation objects from db" do
            u = Factory.create_user([:with_valid_password])
            note = Note.create!(text: "some text", notable_id: u.id, notable_type: "User")
            note.notable.should be_a(User)
            note.notable.as(User).id.should eq(u.id)
          end

          it "doesn't hit db when foreign key or polymorphic type is empty" do
            note = Factory.create_note
            count = query_count
            note.notable.nil?.should be_true
            query_count.should eq(count)
          end

          it "will not hit db again if previous call returns empty array" do
            note = Factory.create_note
            note.notable_type = "User"
            note.notable_id = 1
            count = query_count
            note.notable.nil?.should be_true
            query_count.should eq(count + 1)
            note.notable
            query_count.should eq(count + 1)
          end

          context "new record" do
            it "doesn't hit the db" do
              n = Factory.build_note
              count = query_count
              n.notable
              query_count.should eq(count)
            end
          end

          describe "with class suffix" do
            it "returns casted instance" do
              Factory.create_note([:with_contact]).notable_contact.should be_a(Contact)
              Factory.create_note([:with_user]).notable_user.should be_a(User)
            end
          end
        end

        describe "#add_/relation_name/" do
          context "with given hash" do
            it "builds new object" do
              note = Factory.create_note
              note.add_notable({"name" => "Jack", "age" => 16, "notable_type" => "Contact"})
              note.notable.should be_a(Contact)
              note.notable_contact.name.should eq("Jack")
              note.notable_id.should_not be_nil
              note.notable_type.should eq("Contact")
            end
          end

          context "with given object" do
            it "builds new object" do
              note = Factory.create_note
              c = Factory.create_contact
              note.add_notable(c)
              note.notable.should be_a(Contact)
              note.notable_contact.name.should eq(c.name)
              note.notable_id.should eq(c.id)
              note.notable_type.should eq("Contact")
            end
          end
        end

        describe "#/relation_name/_reload" do
          it "reloads objects" do
            c = Factory.create_contact
            n = Factory.create_note(notable_id: c.id, notable_type: "Contact")
            n.notable
            c.name = "some new name"
            c.save
            n.notable_reload.as(Contact).name.should eq("some new name")
          end
        end

        describe "#remove_/relation_name/" do
          it "removes foreign key and removes it from array" do
            n = Factory.create_note([:with_contact])
            n.notable
            n.remove_notable
            n.notable.should be_nil
            n.reload
            n.notable_id.should be_nil
            n.notable_type.should be_nil
          end
        end
      end

      describe "optional" do
        it "adds validation message when relation is required" do
          n = NoteWithRequiredDependency.find!(Factory.create_note.id)
          n.should validate(:notable).with("must exist")
          n.add_notable(Factory.create_facebook_profile)
          n.valid?.should be_true
        end

        it "allows to use custom validation message" do
          n = NoteWithRequiredDependencyProcMessage.find!(Factory.create_note.id)
          n.should validate(:notable).with("notable is missing")
          n.add_notable(Factory.create_facebook_profile)
          n.valid?.should be_true
        end
      end
    end

    describe "%has_one" do
      it "adds relation name to RELATIONS constant" do
        Contact::RELATIONS.has_key?("addresses").should be_true
      end

      describe "query" do
        it "sets correct query part" do
          Contact.relation("passport").as(Jennifer::Relation::HasOne).condition_clause.as_sql
            .should eq(%(#{quote_identifier("passports.contact_id")} = #{quote_identifier("contacts.id")}))
        end

        context "when declaration has additional block" do
          it "sets correct query part" do
            sql_reg = /#{reg_quote_identifier("addresses.contact_id")} = #{reg_quote_identifier("contacts.id")} AND #{reg_quote_identifier("addresses.main")}/
            Contact.relation("main_address").as(Jennifer::Relation::HasOne).condition_clause.as_sql
              .should match(sql_reg)
          end
        end
      end

      describe "#/relation_name/_query" do
        it "returns query object" do
          c = Factory.create_contact
          q = c.main_address_query
          q.as_sql
            .should match(/#{reg_quote_identifier("addresses.contact_id")} = %s AND #{reg_quote_identifier("addresses.main")}/)
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

        context "with defined inverse_of" do
          it "sets owner during building collection" do
            c = Factory.create_contact
            Factory.create_address(contact_id: c.id, main: true)
            count = query_count
            c.main_address!.contact
            query_count.should eq(count + 1)
          end

          it "sets owner during building collection 2" do
            c = Factory.create_contact
            Factory.create_passport(contact_id: c.id)
            count = query_count
            c.passport!.contact
            query_count.should eq(count + 1)
          end
        end

        context "new record" do
          it "doesn't hit the db" do
            c = Factory.build_contact
            count = query_count
            c.addresses
            query_count.should eq(count)
          end
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

      describe "polymorphic" do
        relation = ProfileWithOneNote.relation("note").as(Jennifer::Relation::PolymorphicHasOne)

        describe "query" do
          it "sets correct query part" do
            relation.condition_clause.as_sql
              .should eq(%(#{quote_identifier("notes.notable_id")} = #{quote_identifier("profiles.id")} AND #{quote_identifier("notes.notable_type")} = %s))
            relation.condition_clause.sql_args.should eq(db_array("ProfileWithOneNote"))
          end
        end

        describe "#/relation_name/_query" do
          it "returns query object" do
            p = ProfileWithOneNote.find!(Factory.create_facebook_profile(type: "ProfileWithOneNote").id)
            q = p.note_query
            q.as_sql.should match(/#{reg_quote_identifier("notes.notable_id")} = %s AND #{reg_quote_identifier("notes.notable_type")} = %s/)
            q.sql_args.should eq(db_array(p.id, "ProfileWithOneNote"))
          end
        end

        describe "#/relation_name/" do
          it "loads relation objects from db" do
            p = ProfileWithOneNote.find!(Factory.create_facebook_profile(type: "ProfileWithOneNote").id)
            n = Factory.create_note(notable_id: p.id, notable_type: "ProfileWithOneNote")
            p.note!.id.should eq(n.id)
          end
        end
      end
    end

    describe "%has_and_belongs_many" do
      describe "query" do
        it "sets correct query part" do
          query = ContactWithDependencies.relation("u_countries").as(Jennifer::Relation::ManyToMany)
          query.condition_clause.as_sql
            .should eq(%(#{quote_identifier("countries.contact_id")} = #{quote_identifier("contacts.id")} AND #{quote_identifier("countries.name")} LIKE %s))
          query.condition_clause.sql_args.should eq(db_array("U%"))
        end
      end

      describe "#/relation_name/_query" do
        it "returns query object" do
          c = Factory.create_contact
          q = c.countries_query
          select_query(q)
            .should match(/JOIN #{reg_quote_identifier("contacts_countries")} ON #{reg_quote_identifier("contacts_countries.country_id")} = #{reg_quote_identifier("countries.id")} AND #{reg_quote_identifier("contacts_countries.contact_id")} = %s/)
          q.sql_args.should eq(db_array(c.id))
        end

        context "relation is a sti subclass" do
          it "returns proper objects" do
            c = Factory.create_contact
            q = c.facebook_many_profiles_query
            select_query(q)
              .should match(/JOIN #{reg_quote_identifier("contacts_profiles")} ON #{reg_quote_identifier("contacts_profiles.profile_id")} = #{reg_quote_identifier("profiles.id")} AND #{reg_quote_identifier("contacts_profiles.contact_id")} = %s/)
            select_query(q)
              .should match(/#{reg_quote_identifier("profiles.type")} = %s/)
            q.sql_args.includes?("FacebookProfile").should be_true
          end

          it "works as well in inverse direction" do
            c = Factory.create_facebook_profile
            q = c.facebook_contacts_query
            select_query(q)
              .should match(/JOIN #{reg_quote_identifier("contacts_profiles")} ON #{reg_quote_identifier("contacts_profiles.contact_id")} = #{reg_quote_identifier("contacts.id")} AND #{reg_quote_identifier("contacts_profiles.profile_id")} = %s/)
            q.sql_args.should eq(db_array(c.id))
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

        context "new record" do
          it "doesn't hit the db" do
            c = Factory.build_contact
            count = query_count
            c.addresses
            query_count.should eq(count)
          end
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

    describe "#relation_retrieved" do
      describe "sti" do
        context "with unknown relation" do
          it { expect_raises(Jennifer::UnknownRelation) { Factory.create_facebook_profile.relation_retrieved("unknown") } }
        end

        context "with own relation" do
          it { Factory.create_facebook_profile.relation_retrieved("facebook_contacts") }
        end

        context "with parent relation" do
          it { Factory.create_facebook_profile.relation_retrieved("contact") }
        end
      end

      context "with unknown relation" do
        it { expect_raises(Jennifer::UnknownRelation) { Factory.create_contact.relation_retrieved("unknown") } }
      end

      context "with own relation" do
        it { Factory.create_contact.relation_retrieved("passport") }
      end
    end
  end
end
