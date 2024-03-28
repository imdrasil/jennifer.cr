require "../spec_helper"

class ModelWithIntName < Jennifer::Model::Base
  mapping({
    id:   Primary64,
    name: Int32,
  })
end

module SomeModule
  class SomeModel < Jennifer::Model::Base
    mapping(id: Primary64)
  end

  class AnotherModel < Jennifer::Model::Base
    mapping(id: Primary64)

    def self.table_prefix
      "custom_table_prefix_"
    end
  end
end

abstract class SuperModel < Jennifer::Model::Base
  def self.table_prefix
    "custom_table_prefix_"
  end
end

class ModelWithTablePrefix < SuperModel
  mapping(id: Primary32)
end

describe Jennifer::Model::Base do
  generator = Jennifer::Adapter.default_adapter.sql_generator

  describe "%scope" do
    context "with block" do
      it "executes in query context" do
        generator.select(Contact.all.ordered)
          .should match(/ORDER BY #{generator.quote_identifier("contacts")}\.#{generator.quote_identifier("name")} ASC/)
      end

      context "without argument" do
        it "is accessible from query object" do
          Contact.all.main.as_sql
            .should match(/#{generator.quote_identifier("contacts")}\.#{generator.quote_identifier("age")} >/)
        end
      end

      context "with argument" do
        it "is accessible from query object" do
          Contact.all.older(12)
            .as_sql.should match(/#{generator.quote_identifier("contacts")}\.#{generator.quote_identifier("age")} >=/)
        end
      end

      context "same names" do
        it "is accessible from query object" do
          Address.all.main.as_sql.should match(/#{generator.quote_identifier("addresses")}\.#{generator.quote_identifier("main")}/)
          Contact.all.main.as_sql.should match(/#{generator.quote_identifier("contacts")}\.#{generator.quote_identifier("age")} >/)
        end
      end

      it "is chainable" do
        c1 = Factory.create_contact(age: 15)
        c2 = Factory.create_contact(age: 15)
        c3 = Factory.create_contact(age: 13)
        Factory.create_address(contact_id: c1.id, main: true)
        Factory.create_address(contact_id: c2.id, main: false)
        Factory.create_address(contact_id: c3.id, main: true)
        Contact.all.with_main_address.older(14).count.should eq(1)
      end
    end

    context "with query object class" do
      it "executes in class context" do
        generator.select(Contact.johny).should match(/#{generator.quote_identifier("name")} =/)
      end

      context "without argument" do
        it "is accessible from query object" do
          Contact.johny.as_sql
            .should match(/#{generator.quote_identifier("contacts")}\.#{generator.quote_identifier("name")} =/)
        end
      end

      context "with argument" do
        it do
          Contact.by_gender("female").as_sql
            .should match(/#{generator.quote_identifier("contacts")}\.#{generator.quote_identifier("gender")} =/)
        end
      end

      it "is chainable" do
        c1 = Factory.create_contact(name: "Johny")
        c3 = Factory.create_contact
        Factory.create_address(contact_id: c1.id, main: true)
        Factory.create_address(contact_id: c3.id, main: true)
        Contact.with_main_address.johny.count.should eq(1)
      end
    end
  end

  describe ".primary" do
    it "return criteria with primary key" do
      c = Passport.primary
      match_fields(c, table: "passports", field: "enn")
    end
  end

  describe ".primary_field_name" do
    it "returns name of custom primary field" do
      Passport.primary_field_name.should eq("enn")
    end

    it "returns name of default primary field name" do
      Contact.primary_field_name.should eq("id")
    end
  end

  describe ".create" do
    it "doesn't raise exception if object is invalid" do
      country = Country.create
      country.should_not be_valid
      country.id.should be_nil
    end

    context "without arguments" do
      it "builds new object without any exception" do
        c = ContactWithNotStrictMapping.create
        c.id.should_not be_nil
        c.name.should be_nil
      end

      it "builds new object passing it to block" do
        c = ContactWithNotStrictMapping.create(&.name = "John")
        c.id.should_not be_nil
        c.name.should eq("John")
      end
    end

    context "from hash" do
      context "with string keys" do
        it "creates object" do
          contact = Contact.create({"name" => "Deepthi", "age" => 18, "gender" => "female"})
          contact.id.should_not be_nil
          match_fields(contact, name: "Deepthi", age: 18, gender: "female")
        end

        it "builds new object passing it to block" do
          c = Contact.create({"name" => "Deepthi", "age" => 18}) { |obj| obj.gender = "female" }
          c.id.should_not be_nil
          match_fields(c, name: "Deepthi", age: 18, gender: "female")
        end
      end

      context "with symbol keys" do
        it "creates object" do
          contact = Contact.create({:name => "Deepthi", :age => 18, :gender => "female"})
          contact.id.should_not be_nil
          match_fields(contact, name: "Deepthi", age: 18, gender: "female")
        end

        it "builds new object passing it to block" do
          c = Contact.create({:name => "Deepthi", :age => 18}) { |obj| obj.gender = "female" }
          c.id.should_not be_nil
          match_fields(c, name: "Deepthi", age: 18, gender: "female")
        end
      end
    end

    context "from named tuple" do
      it "properly creates object" do
        contact = Contact.create({name: "Deepthi", age: 18, gender: "female"})
        contact.id.should_not be_nil
        match_fields(contact, name: "Deepthi", age: 18, gender: "female")
      end

      it "allows splatted named tuple as well" do
        contact = Contact.create(name: "Deepthi", age: 18, gender: "female")
        contact.id.should_not be_nil
        match_fields(contact, name: "Deepthi", age: 18, gender: "female")
      end

      it "builds new object passing it to block" do
        c = Contact.create(name: "Deepthi", age: 18) { |obj| obj.gender = "female" }
        c.id.should_not be_nil
        match_fields(c, name: "Deepthi", age: 18, gender: "female")
      end
    end

    context "strict mapping" do
      it "raises exception if not all fields are described" do
        Factory.create_contact
        expect_raises(::Jennifer::BaseException) do
          Contact.all.each_result_set do |rs|
            begin
              ContactWithNotAllFields.build(rs)
            ensure
              rs.read_to_end
            end
          end
        end
      end

      it "raised exception includes query explanation" do
        select_regexp = /[\S\s]*SELECT #{generator.quote_identifier("contacts")}\.\*/i
        Factory.create_contact
        expect_raises(::Jennifer::BaseException, select_regexp) do
          Contact.all.each_result_set do |rs|
            ContactWithNotAllFields.build(rs)
          end
        end
      end

      it "result set has no some field" do
        OneFieldModel.create({} of String => Jennifer::DBAny)
        error_message = "Column OneFieldModelWithExtraArgument.missing_field hasn't been found in the result set."
        expect_raises(Jennifer::BaseException, error_message) do
          OneFieldModelWithExtraArgument.all.to_a
        end
      end
    end

    context "non strict mapping" do
      it "ignores all extra fields" do
        ContactWithNotStrictMapping.create({name: "some name"})
        model = ContactWithNotStrictMapping.all.last!
        model.name.should eq("some name")
      end
    end

    context "model has column aliases" do
      it "correctly maps column aliases" do
        a = Author.create(name1: "Samply", name2: "Examplary")

        Author.all.find_by!({:first_name => "Samply"}).id.should eq(a.id)
      end
    end

    context "with non-auto primary key" do
      it do
        NoteWithManualId.create(id: 1) # ?
        NoteWithManualId.all.where { _id == 1 }.exists?.should be_true
      end
    end
  end

  describe ".create!" do
    it "raises exception if object is invalid" do
      expect_raises(Jennifer::RecordInvalid) do
        Country.create!
      end
    end

    context "without arguments" do
      it "builds new object without any exception" do
        c = ContactWithNotStrictMapping.create!
        c.id.should_not be_nil
        c.name.should be_nil
      end

      it "builds new object passing it to block" do
        c = ContactWithNotStrictMapping.create!(&.name = "John")
        c.id.should_not be_nil
        c.name.should eq("John")
      end
    end

    context "from hash" do
      context "with string keys" do
        it "properly creates object" do
          contact = Contact.create!({"name" => "Deepthi", "age" => 18, "gender" => "female"})
          contact.id.should_not be_nil
          match_fields(contact, name: "Deepthi", age: 18, gender: "female")
        end

        it "builds new object passing it to block" do
          c = Contact.create!({"name" => "Deepthi", "age" => 18}) { |obj| obj.gender = "female" }
          c.id.should_not be_nil
          match_fields(c, name: "Deepthi", age: 18, gender: "female")
        end
      end

      context "with symbol keys" do
        it "properly creates object" do
          contact = Contact.create!({:name => "Deepthi", :age => 18, :gender => "female"})
          contact.id.should_not be_nil
          match_fields(contact, name: "Deepthi", age: 18, gender: "female")
        end

        it "builds new object passing it to block" do
          c = Contact.create!({:name => "Deepthi", :age => 18}) { |obj| obj.gender = "female" }
          c.id.should_not be_nil
          match_fields(c, name: "Deepthi", age: 18, gender: "female")
        end
      end
    end

    context "from named tuple" do
      it "properly creates object" do
        contact = Contact.create!({name: "Deepthi", age: 18, gender: "female"})
        contact.id.should_not be_nil
        match_fields(contact, name: "Deepthi", age: 18, gender: "female")
      end

      it "allows splatted named tuple as well" do
        contact = Contact.create!(name: "Deepthi", age: 18, gender: "female")
        contact.id.should_not be_nil
        match_fields(contact, name: "Deepthi", age: 18, gender: "female")
      end

      it "builds new object passing it to block" do
        c = Contact.create!(name: "Deepthi", age: 18) { |obj| obj.gender = "female" }
        c.id.should_not be_nil
        match_fields(c, name: "Deepthi", age: 18, gender: "female")
      end
    end
  end

  describe ".build" do
    context "without arguments" do
      it "builds new object without any exception" do
        p = Passport.build
        p.enn.nil?.should be_true
        p.contact_id.nil?.should be_true
      end
    end

    context "from hash" do
      context "with string keys" do
        context "strict mapping" do
          it "raises exception if some field can't be casted" do
            error_message = "Column OneFieldModelWithExtraArgument.missing_field can't be casted from Nil to it's type - String"
            expect_raises(Jennifer::BaseException, error_message) do
              OneFieldModelWithExtraArgument.build({} of String => Jennifer::DBAny)
            end
          end
        end

        it "properly creates object" do
          contact = Contact.build({"name" => "Deepthi", "age" => 18, "gender" => "female"})
          match_fields(contact, name: "Deepthi", age: 18, gender: "female")
        end
      end

      context "with symbol keys" do
        it "properly creates object" do
          contact = Contact.build({:name => "Deepthi", :age => 18, :gender => "female"})
          match_fields(contact, name: "Deepthi", age: 18, gender: "female")
        end
      end

      context "without arguments" do
        it "allows one field models" do
          OneFieldModel.build
        end
      end

      context "given result set" do
        it "allows one field models" do
          model = OneFieldModel.create
          is_executed = false
          OneFieldModel.where { _id == model.id }.each_result_set do |rs|
            OneFieldModel.build(rs).id.should eq(model.id)
            is_executed = true
          end
          is_executed.should be_true
        end
      end
    end

    context "from named tuple" do
      it "properly creates object" do
        contact = Contact.build({name: "Deepthi", age: 18, gender: "female"})
        match_fields(contact, name: "Deepthi", age: 18, gender: "female")
      end

      it "allows splatted named tuple as well" do
        contact = Contact.build(name: "Deepthi", age: 18, gender: "female")
        match_fields(contact, name: "Deepthi", age: 18, gender: "female")
      end
    end
  end

  describe ".table_name" do
    it { Contact.table_name.should eq("contacts") }
    it { ModelWithTablePrefix.table_name.should eq("custom_table_prefix_model_with_table_prefixes") }

    it "returns specified name" do
      ContactWithNotAllFields.table_name.should eq("contacts")
    end

    describe "STI" do
      it { TwitterProfile.table_name.should eq("profiles") }
    end

    describe "inside of module" do
      it { SomeModule::SomeModel.table_name.should eq("some_module_some_models") }
      it { SomeModule::AnotherModel.table_name.should eq("custom_table_prefix_another_models") }
    end
  end

  describe ".foreign_key_name" do
    it { Contact.foreign_key_name.should eq("contact_id") }
    it { ModelWithTablePrefix.foreign_key_name.should eq("custom_table_prefix_model_with_table_prefix_id") }

    it "returns specified name" do
      ContactWithNotAllFields.foreign_key_name.should eq("contact_id")
    end

    describe "STI" do
      it { TwitterProfile.foreign_key_name.should eq("profile_id") }
    end

    describe "inside of module" do
      it { SomeModule::SomeModel.foreign_key_name.should eq("some_module_some_model_id") }
      it { SomeModule::AnotherModel.foreign_key_name.should eq("custom_table_prefix_another_model_id") }
    end
  end

  describe ".c" do
    it "creates criteria with given name" do
      c = Contact.c("some_field")
      c.is_a?(Jennifer::QueryBuilder::Criteria)
      c.field.should eq("some_field")
      c.table.should eq("contacts")
      c.relation.should be_nil
    end

    it "creates criteria with given name and relation" do
      c = Contact.c("some_field", "some_relation")
      c.is_a?(Jennifer::QueryBuilder::Criteria)
      match_fields(c, field: "some_field", table: "contacts", relation: "some_relation")
    end
  end

  describe ".transaction" do
    it "allow to start transaction" do
      void_transaction do
        expect_raises(DivisionByZeroError) do
          Contact.transaction do
            Factory.create_contact
            1 // 0
          end
        end
        Contact.all.count.should eq(0)
      end
    end
  end

  describe ".all" do
    it "returns empty query" do
      Contact.all.empty?.should be_true
    end

    pair_only do
      it "creates query with right adapter" do
        PairAddress.all.@adapter.should eq(PAIR_ADAPTER)
      end
    end
  end

  describe ".destroy" do
    it "deletes from db by given ids" do
      c = [] of Int64?
      3.times { c << Factory.create_contact.id }
      Contact.destroy(c[0..1])
      Contact.all.count.should eq(1)
    end

    it "invokes destroy callbacks" do
      address = Factory.create_address
      count = Address.destroy_counter
      Address.destroy([address.id])
      (Address.destroy_counter - count).should eq(1)
    end
  end

  describe ".delete" do
    it "deletes from db by given ids" do
      c = [] of Int64?
      3.times { c << Factory.create_contact.id }
      Contact.delete(c[0..1])
      Contact.all.count.should eq(1)
    end

    it "doesn't invoke destroy callbacks" do
      address = Factory.create_address
      count = Address.destroy_counter
      Address.delete([address.id])
      Address.destroy_counter.should eq(count)
    end
  end

  describe ".models" do
    it "returns all model classes" do
      models = Jennifer::Model::Base.models
      models.is_a?(Array).should be_true
      # I tired from modifying this each time new model is added
      (models.size > 6).should be_true
    end

    it { Contact.models.empty?.should be_true }
    it { Profile.models.should eq([FacebookProfile, TwitterProfile]) }
  end

  describe ".import" do
    argument_regex = db_specific(mysql: ->{ /\(\?/ }, postgres: ->{ /\(\$\d/ })
    amount = db_specific(mysql: ->{ 3641 }, postgres: ->{ 3277 })

    context "with autoincrementable primary key" do
      context "when count of fields doesn't exceed limit" do
        it "imports objects by " do
          objects = Factory.build_contact(amount - 1)

          Contact.all.count.should eq(0)
          Contact.import(objects)
          query_log[1][:query].to_s.should match(argument_regex)
          Contact.all.count.should eq(amount - 1)
        end
      end

      context "when count of fields exceeds limit" do
        it "imports objects by " do
          objects = Factory.build_contact(amount)

          Contact.all.count.should eq(0)
          Contact.import(objects)
          query_log[1][:query].to_s.should_not match(argument_regex)
          Contact.all.count.should eq(amount)
        end
      end

      # it "sets ids to all given objects" do
      #   void_transaction do
      #     objects = Factory.build_contact(2)
      #     new_collection = Contact.import(objects)
      #     objects.should eq(new_collection)
      #     objects[0].id.nil?.should be_false
      #     objects[1].id.nil?.should be_false
      #   end
      # end
    end

    context "with custom primary key" do
      it "imports objects" do
        objects = [Factory.build_address(enn: "qwer"), Factory.build_address(enn: "zxcc")]
        objects.each { |obj| obj.created_at = obj.updated_at = Time.local }
        Address.import(objects)
        Address.all.count.should eq(2)
      end
    end
  end

  describe ".upsert" do
    it "do nothing on conflict when inserting" do
      contact = Factory.create_contact(description: "unique", age: 23)

      c1 = Factory.build_contact(age: 13, description: "unique")
      c2 = Factory.build_contact(age: 31, description: "not unique")
      Contact.upsert([c1, c2])
      Contact.all.pluck(:age).should eq([contact.age, c2.age])
    end

    it "treats given hash as on conflict definition" do
      Factory.create_contact(description: "unique", age: 23)

      c1 = Factory.build_contact(age: 13, description: "unique")
      c2 = Factory.build_contact(age: 31, description: "not unique")
      Contact.upsert([c1, c2], %w[description]) do
        {:description => concat_ws(" ", values(:description), sql("'updated'", false))}
      end
      Contact.all.order(id: :asc).pluck(:description).should eq(["#{c1.description} updated", c2.description])
    end
  end

  describe ".actual_table_field_count" do
    it "returns count of fields that has corresponding db table" do
      Address.actual_table_field_count.should eq(7)
    end

    pair_only do
      it "respects connection" do
        PairAddress.actual_table_field_count.should eq(4)
      end
    end
  end

  describe "#changed?" do
    it "returns true if at list one field was changed" do
      c = Factory.build_contact
      c.name = "new name"
      c.changed?.should be_true
    end

    it "returns false if no one field was changed" do
      Factory.build_contact.changed?.should be_false
    end
  end

  describe "#init_primary_field" do
    it "sets primary field" do
      c = Factory.build_contact
      c.init_primary_field(1)
      c.primary.should eq(1)
    end

    it "raises error if it is set" do
      c = Factory.build_contact
      c.init_primary_field(1)
      expect_raises(Exception, "Primary field is already initialized") do
        c.init_primary_field(1)
      end
    end
  end

  describe "#new_record?" do
    it "returns true if primary field nil" do
      Factory.build_contact.new_record?.should be_true
    end

    it "returns false if primary field is not nil" do
      Factory.create_contact.new_record?.should be_false
    end
  end

  describe "#save" do
    it "saves new object to db" do
      count = Contact.all.count
      contact = Factory.build_contact
      contact.save
      Contact.all.count.should eq(count + 1)
    end

    context "updates existing object in db" do
      it "stores changed fields to db" do
        c = Factory.create_contact
        c.name = "new name"
        c.save
        Contact.find!(c.id).name.should eq("new name")
      end

      it "returns true if record was saved" do
        c = Factory.create_contact
        c.id.nil?.should be_false
        c.name = "new name"
        c.save.should be_true
        Contact.all.count.should eq(1)
      end

      it "returns true if record wasn't changed" do
        Factory.create_address.save.should be_true
        Address.all.count.should eq(1)
      end

      it "returns false if record wasn't saved" do
        record = Factory.create_address
        record.street = "invalid"
        record.save.should be_false
      end

      it "calls after_save_callback" do
        c = Factory.create_contact
        c.name = "new name"
        c.save
        c.name_changed?.should be_false
      end
    end

    context "when brakes unique index" do
      it "raises exception" do
        void_transaction do
          Factory.create_address(street: "st. 2")
          expect_raises(Jennifer::BaseException) do
            Factory.create_address(street: "st. 2")
          end
        end
      end
    end

    pair_only do
      it "respects specified adapter" do
        PairAddress.new.save
        PairAddress.all.count.should eq(1)
        Address.all.count.should eq(0)
      end
    end
  end

  describe "#destroy" do
    it "deletes from db" do
      contact = Factory.create_contact
      contact.destroy
      Contact.all.exists?.should be_false
    end

    it "invokes destroy callbacks" do
      address = Factory.create_address
      count = Address.destroy_counter
      address.destroy
      (Address.destroy_counter - count).should eq(1)
    end
  end

  describe "#delete" do
    it "deletes from db by given ids" do
      contact = Factory.create_contact
      contact.delete
      Contact.all.exists?.should be_false
    end

    it "doesn't invoke destroy callbacks" do
      address = Factory.create_address
      count = Address.destroy_counter
      address.delete
      Address.destroy_counter.should eq(count)
    end
  end

  describe "#lock!" do
    it "lock current record" do
      Factory.create_contact.lock!
      query_log.last[:query].to_s.should match(/FOR UPDATE/)
    end

    it "raises exception if transaction is not started" do
      void_transaction do
        Factory.create_contact.lock!
      end
    end
  end

  describe "#with_lock" do
    it "starts transaction" do
      void_transaction do
        expect_raises(DivisionByZeroError) do
          Factory.create_contact.with_lock do
            Factory.create_contact
            Contact.all.count.should eq(2)
            1 // 0
          end
        end
        Contact.all.count.should eq(1)
      end
    end

    it "locks for update" do
      Factory.create_contact.with_lock do
        query_log.last[:query].to_s.should match(/FOR UPDATE/)
      end
    end
  end

  describe "#set_attributes" do
    context "when given attribute exists" do
      it "raises exception if value has wrong type" do
        c = Factory.build_contact
        expect_raises(::Jennifer::BaseException) do
          c.set_attributes({:name => 123})
        end
      end

      it "marks changed field as modified" do
        c = Factory.build_contact
        c.set_attributes({"name" => "asd"})
        c.name.should eq("asd")
        c.name_changed?.should be_true
      end
    end

    context "when no such setter" do
      it "raises exception" do
        c = Factory.build_contact
        expect_raises(::Jennifer::BaseException) do
          c.set_attributes({:asd => 123})
        end
      end
    end

    context "with named tuple" do
      it do
        c = Factory.build_contact
        c.set_attributes({name: "asd"})
        c.name.should eq("asd")
      end
    end

    context "with splatted named tuple" do
      it do
        c = Factory.build_contact
        c.set_attributes(name: "asd")
        c.name.should eq("asd")
      end

      it do
        subject = ModelWithIntName.build(name: 1)
        subject.set_attributes(name: 2)
        subject.name.should eq(2)
      end
    end
  end

  describe "#update" do
    context "when given attribute exists" do
      it "stores given fields" do
        c = Factory.create_contact
        c.update({"name" => "asd"})
        Contact.all.where { _name == "asd" }.exists?.should be_true
      end
    end

    context "when no such setter" do
      it "raises exception" do
        c = Factory.build_contact
        expect_raises(::Jennifer::BaseException) do
          c.update({:asd => 123})
        end
      end
    end

    context "with splatted named tuple" do
      it do
        c = Factory.create_contact
        c.update(name: "asd")
        Contact.all.where { _name == "asd" }.exists?.should be_true
      end
    end

    it "doesn't store invalid data" do
      c = Factory.create_contact
      c.update(age: 12).should be_false
      Contact.where { _age == 12 }.exists?.should be_false
    end
  end

  describe "#update!" do
    context "when given attribute exists" do
      it "stores given fields" do
        c = Factory.create_contact
        c.update!({"name" => "asd"})
        Contact.all.where { _name == "asd" }.exists?.should be_true
      end
    end

    context "when no such setter" do
      it "raises exception" do
        c = Factory.build_contact
        expect_raises(::Jennifer::BaseException) do
          c.update!({:asd => 123})
        end
      end
    end

    context "with splatted named tuple" do
      it do
        c = Factory.create_contact
        c.update!(name: "asd")
        Contact.all.where { _name == "asd" }.exists?.should be_true
      end
    end

    it "doesn't store invalid data" do
      expect_raises(Jennifer::RecordInvalid) do
        c = Factory.create_contact
        c.update!(age: 12)
      end
    end
  end

  describe "#inspect" do
    it do
      address = Factory.build_address
      address.inspect.should eq("#<Address:0x#{address.object_id.to_s(16)} id: nil, main: false, street: \"#{address.street}\"," \
                                " contact_id: nil, details: nil, created_at: nil, updated_at: nil>")
    end

    it do
      profile = Factory.build_facebook_profile
      profile.inspect.should eq("#<FacebookProfile:0x#{profile.object_id.to_s(16)} uid: \"1234\", " \
                                "virtual_child_field: nil, id: nil, login: \"some_login\", " \
                                "contact_id: nil, type: \"FacebookProfile\", virtual_parent_field: nil>")
    end
  end

  describe "#to_json" do
    it "works with all possible column types" do
      AllTypeModel.new.to_json.should eq(
        db_specific(
          mysql: ->do
            <<-JSON
            {"id":null,"bool_f":null,"bigint_f":null,"integer_f":null,"short_f":null,"float_f":null,
            "double_f":null,"string_f":null,"varchar_f":null,"text_f":null,"timestamp_f":null,
            "date_time_f":null,"date_f":null,"json_f":null,"tinyint_f":null,"decimal_f":null,"blob_f":null}
            JSON
          end,
          postgres: ->do
            <<-JSON
            {"id":null,"bool_f":null,"bigint_f":null,"integer_f":null,"short_f":null,"float_f":null,
            "double_f":null,"string_f":null,"varchar_f":null,"text_f":null,"timestamp_f":null,
            "date_time_f":null,"date_f":null,"json_f":null,"decimal_f":null,"oid_f":null,"char_f":null,
            "uuid_f":null,"timestamptz_f":null,"bytea_f":null,"jsonb_f":null,"xml_f":null,"point_f":null,
            "lseg_f":null,"path_f":null,"box_f":null,"array_int32_f":null,"array_string_f":null,"array_time_f":null}
            JSON
          end
        ).gsub('\n', "")
      )
    end

    it "includes STI fields" do
      Factory.build_twitter_profile.to_json.should eq(
        %({"id":null,"login":"some_login","contact_id":null,"type":"TwitterProfile","email":"some_email@example.com"})
      )
    end

    it "includes all fields by default" do
      record = Factory.build_passport
      record.to_json.should eq(%({"enn":"dsa","contact_id":null}))
    end

    it "allows to specify *only* argument solely" do
      record = Factory.build_passport
      record.to_json(%w[enn]).should eq(%({"enn":"dsa"}))
    end

    it "allows to specify *except* argument solely" do
      record = Factory.build_passport
      record.to_json(except: %w[enn]).should eq(%({"contact_id":null}))
    end

    context "with block" do
      it "allows to extend json using block" do
        executed = false
        record = Factory.build_passport
        record.to_json do |json, obj|
          executed = true
          obj.should eq(record)
          json.field "custom", "value"
        end.should eq(%({"enn":"dsa","contact_id":null,"custom":"value"}))
        executed.should be_true
      end

      it "respects :only option" do
        record = Factory.build_passport
        record.to_json(%w[enn]) do |json|
          json.field "custom", "value"
        end.should eq(%({"enn":"dsa","custom":"value"}))
      end

      it "respects :except option" do
        record = Factory.build_passport
        record.to_json(except: %w[enn]) do |json|
          json.field "custom", "value"
        end.should eq(%({"contact_id":null,"custom":"value"}))
      end
    end
  end
end
