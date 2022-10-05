require "../spec_helper"

postgres_only do
  class ContactWithArray < ApplicationRecord
    mapping({
      id:   Primary64,
      tags: Array(Int32),
    })
  end

  class PgContactWithBigDecimal < ApplicationRecord
    table_name "contacts"

    mapping({
      id:       Primary64,
      name:     String,
      ballance: {type: BigDecimal, converter: Jennifer::Model::BigDecimalConverter(PG::Numeric), scale: 2},
    }, false)
  end
end

mysql_only do
  class PgContactWithBigDecimal < ApplicationRecord
    table_name "contacts"

    mapping({
      id:       Primary64,
      name:     String,
      ballance: {type: BigDecimal, converter: Jennifer::Model::BigDecimalConverter(Float64), scale: 2},
    }, false)
  end
end

private module Mapping11
  include Jennifer::Macros
  include Jennifer::Model::Mapping

  mapping(
    id: Primary64
  )
end

private module Mapping12
  include Jennifer::Macros
  include Jennifer::Model::Mapping

  mapping(
    name: String?
  )
end

private module CompositeMapping
  include Mapping11
  include Mapping12

  mapping(
    password_digest: String?
  )
end

private module ModuleWithoutMapping
  include CompositeMapping
end

class UserWithModuleMapping < Jennifer::Model::Base
  include ModuleWithoutMapping

  table_name "users"

  mapping(
    email: String?
  )
end

class UserWithConverter < Jennifer::Model::Base
  table_name "users"

  mapping(
    id: Primary64,
    name: {type: JSON::Any, converter: Jennifer::Model::JSONConverter}
  )
end

describe Jennifer::Model::Mapping do
  generator = Jennifer::Adapter.default_adapter.sql_generator

  describe "#reload" do
    it "assign all values from db to existing object" do
      c1 = Factory.create_contact
      c2 = Contact.all.first!
      c1.age = 55
      c1.save!
      c2.reload
      c2.age.should eq(55)
    end

    it "raises exception with errors if invalid on save!" do
      contact = Factory.create_contact
      contact.age = 12
      contact.name = "much too long for name"
      contact.description = "much too long for description"
      begin
        contact.save!
        fail("should raise validation exception")
      rescue ex : Jennifer::RecordInvalid
        contact.errors.size.should eq(3)
        raw_errors = contact.errors
        raw_errors[:age].should eq(["is not included in the list"])
        raw_errors[:name].should eq(["is too long (maximum is 15 characters)"])
        raw_errors[:description].should eq(["Too large description"])
      end
    end
  end

  describe "#attribute_metadata" do
    describe "with symbol argument" do
      it do
        Factory.build_contact.attribute_metadata(:id).should eq({
          type:        Int64?,
          primary:     true,
          parsed_type: "::Union(Int64, ::Nil)",
          column:      "id",
          auto:        true,
          null:        true,
        })
        Factory.build_contact.attribute_metadata(:name)
          .should eq({type: String, parsed_type: "String", column: "name", null: false})
        Factory.build_address.attribute_metadata(:street)
          .should eq({type: String, parsed_type: "String", column: "street", null: false})
      end
    end

    describe "with string argument" do
      it do
        Factory.build_contact.attribute_metadata("id").should eq({
          type:        Int64?,
          primary:     true,
          parsed_type: "::Union(Int64, ::Nil)",
          column:      "id",
          auto:        true,
          null:        true,
        })
        Factory.build_contact.attribute_metadata("name")
          .should eq({type: String, parsed_type: "String", column: "name", null: false})
        Factory.build_address.attribute_metadata("street")
          .should eq({type: String, parsed_type: "String", column: "street", null: false})
      end
    end
  end

  describe "%mapping" do
    describe "converter" do
      postgres_only do
        describe PG::Numeric do
          it "allows passing PG::Numeric" do
            ballance = PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [1i16])
            c = ContactWithFloatMapping.build(ballance: ballance)
            c.ballance.should eq(1.0f64)
            c.ballance.is_a?(Float64)
          end

          it "correctly creates using provided field instead of numeric" do
            ballance = 10f64
            c = ContactWithFloatMapping.build(ballance: ballance)
            c.ballance.should eq(10f64)
            c.ballance.is_a?(Float64).should be_true
          end

          it "correctly loads data from db" do
            ballance = PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [1i16])
            c = ContactWithFloatMapping.create(ballance: ballance)
            contact_with_float = ContactWithFloatMapping.find!(c.id)
            contact_with_float.ballance.should eq(1.0f64)
            contact_with_float.ballance.is_a?(Float64).should be_true
          end

          it "correctly transform data to bigdecimal" do
            Factory.create_contact(ballance: PG::Numeric.new(2i16, 0i16, 0i16, 2i16, [1234i16, 6800i16])).id
            record = PgContactWithBigDecimal.all.last!
            record.ballance.should eq(BigDecimal.new(123468, 2))
          end
        end
      end

      mysql_only do
        describe "numeric" do
          it "correctly transform data to bigdecimal" do
            Factory.create_contact(ballance: 1234.68f64)
            record = PgContactWithBigDecimal.all.last!
            record.ballance.should eq(BigDecimal.new(123468, 2))
          end
        end
      end
    end

    describe ".columns_tuple" do
      it "returns named tuple with column metadata" do
        metadata = Contact.columns_tuple
        metadata.is_a?(NamedTuple).should be_true
        metadata[:id].is_a?(NamedTuple).should be_true
        metadata[:id][:type].should eq(Int64?)
        metadata[:id][:parsed_type].should eq("::Union(Int64, ::Nil)")
      end

      it "ignores column aliases" do
        metadata = Author.columns_tuple
        metadata.is_a?(NamedTuple).should be_true
        metadata[:name1].is_a?(NamedTuple).should be_true
        metadata[:name1][:type].should eq(String)
        metadata[:name1][:parsed_type].should eq("String")
      end

      it "includes fields defined in included module" do
        metadata = UserWithModuleMapping.columns_tuple
        metadata.is_a?(NamedTuple).should be_true
        metadata.has_key?(:id).should be_true
        metadata.has_key?(:name).should be_true
        metadata.has_key?(:password_digest).should be_true
        metadata.has_key?(:email).should be_true
      end
    end

    describe ".field_names" do
      it "doesn't return field names from child models" do
        Profile.field_names.should match_array(%w[id login contact_id type virtual_parent_field])
      end

      it "includes virtual fields" do
        Profile.field_names.should match_array(%w[id login contact_id type virtual_parent_field])
      end
    end

    describe ".column_names" do
      it "doesn't return column names from child models" do
        Profile.column_names.should match_array(%w[id login contact_id type])
      end

      it "doesn't include virtual fields" do
        Profile.column_names.should match_array(%w[id login contact_id type])
      end
    end

    context "columns metadata" do
      it "sets constant" do
        Contact::COLUMNS_METADATA.is_a?(NamedTuple).should be_true
      end

      it "sets primary to true for Primary32 type" do
        Contact::COLUMNS_METADATA[:id][:primary].should be_true
      end

      it "sets primary for Primary64" do
        ContactWithInValidation::COLUMNS_METADATA[:id][:primary].should be_true
      end
    end

    describe ".new" do
      context "loading STI objects from request" do
        it "creates proper objects" do
          Factory.create_twitter_profile
          Factory.create_facebook_profile
          klasses = [] of Profile.class

          Profile.all.each_result_set do |rs|
            record = Profile.new(rs)
            klasses << record.class
          end
          klasses.should match_array([FacebookProfile, TwitterProfile])
        end

        it "raises exception if invalid type was given" do
          p = Factory.create_facebook_profile
          p.update_column("type", "asdasd")
          expect_raises(Jennifer::UnknownSTIType) do
            Profile.all.each_result_set do |rs|
              Profile.new(rs)
            end
          end
        end

        it "creates base class if type field is blank" do
          p = Factory.create_facebook_profile
          p.update_column("type", "")
          executed = false

          Profile.all.each_result_set do |rs|
            Profile.new(rs).class.to_s.should eq("Profile")
            executed = true
          end
          executed.should be_true
        end
      end

      context "from result set" do
        it "properly creates object" do
          executed = false
          Factory.create_contact(name: "Jennifer", age: 20)
          Contact.all.each_result_set do |rs|
            record = Contact.new(rs)
            record.name.should eq("Jennifer")
            record.age.should eq(20)
            executed = true
          end
          executed.should be_true
        end

        it "properly assigns aliased columns" do
          executed = false
          Author.create(name1: "Ann", name2: "OtherAuthor")
          Author.all.each_result_set do |rs|
            record = Author.new(rs)
            record.name1.should eq("Ann")
            record.name2.should eq("OtherAuthor")
            executed = true
          end
          executed.should be_true
        end
      end

      context "from hash" do
        context "with string values for non-string properties" do
          it "coerces types" do
            record = AllTypeModel.new({
              "bool_f"      => "true",
              "bigint_f"    => "12",
              "integer_f"   => "13",
              "short_f"     => "14",
              "float_f"     => "12.0",
              "double_f"    => "15.0",
              "timestamp_f" => "2010-12-10 20:10:10",
            })

            record.bool_f.should be_true
            record.bigint_f.should eq(12i64)
            record.integer_f.should eq(13)
            record.short_f.should eq(14i16)
            record.float_f.should eq(12.0f32)
            record.double_f.should eq(15.0)
            record.timestamp_f.should eq(Time.local(2010, 12, 10, 20, 10, 10, location: ::Jennifer::Config.local_time_zone))
          end
        end

        context "with string keys" do
          it "properly creates object" do
            contact = Contact.new({"name" => "Deepthi", "age" => 18, "gender" => "female"})
            contact.name.should eq("Deepthi")
            contact.age.should eq(18)
            contact.gender.should eq("female")
          end

          it "properly maps column aliases" do
            a = Author.new({"name1" => "Gener", "name2" => "Ric"})
            a.name1.should eq("Gener")
            a.name2.should eq("Ric")
          end
        end

        context "with symbol keys" do
          it "properly creates object" do
            contact = Contact.new({:name => "Deepthi", :age => 18, :gender => "female"})
            contact.name.should eq("Deepthi")
            contact.age.should eq(18)
            contact.gender.should eq("female")
          end

          it "properly maps column aliases" do
            a = Author.new({:name1 => "Ran", :name2 => "Dom"})
            a.name1.should eq("Ran")
            a.name2.should eq("Dom")
          end
        end
      end

      context "from named tuple" do
        it "properly creates object" do
          contact = Contact.new({name: "Deepthi", age: 18, gender: "female"})
          contact.name.should eq("Deepthi")
          contact.age.should eq(18)
          contact.gender.should eq("female")
        end

        it "properly maps column aliases" do
          a = Author.new({name1: "Unk", name2: "Nown"})
          a.name1.should eq("Unk")
          a.name2.should eq("Nown")
        end
      end

      context "without arguments" do
        it "creates object with nil or default values" do
          country = Country.new
          country.id.should be_nil
          country.name.should be_nil
        end

        it "works with default values" do
          c = CountryWithDefault.new
          c.name.should be_nil
          c.virtual.should be_true
        end
      end

      context "model has only id field" do
        it "creates succesfully without arguments" do
          id = OneFieldModel.create.id
          OneFieldModel.find!(id).id.should eq(id)
        end
      end
    end

    describe ".field_count" do
      it "returns correct number of model fields" do
        proper_count = db_specific(
          mysql: ->{ 10 },
          postgres: ->{ 11 }
        )
        Contact.field_count.should eq(proper_count)
      end
    end

    describe "data types" do
      describe "mapping types" do
        describe "Primary32" do
          it "makes field nillable" do
            OneFieldModel.columns_tuple[:id][:parsed_type].should eq("::Union(Int32, ::Nil)")
          end
        end

        describe "Primary64" do
          it "makes field nillable" do
            City.columns_tuple[:id][:parsed_type].should eq("::Union(Int64, ::Nil)")
          end
        end

        describe "user-defined mapping types" do
          it "is accessible if defined in parent class" do
            User::COLUMNS_METADATA[:password_digest].should eq({type: String, column: "password_digest", default: "", parsed_type: "String", null: false})
            User::COLUMNS_METADATA[:email].should eq({type: String, column: "email", default: "", parsed_type: "String", null: false})
          end

          pending "allows to add extra options" do
          end

          pending "allows to override options" do
          end
        end
      end

      describe "BOOLEAN" do
        it "correctly saves and loads" do
          AllTypeModel.create!(bool_f: true)
          AllTypeModel.all.last!.bool_f!.should be_true
        end
      end

      describe "BIGINT" do
        it "correctly saves and loads" do
          AllTypeModel.create!(bigint_f: 15i64)
          AllTypeModel.all.last!.bigint_f!.should eq(15i64)
        end
      end

      describe "INTEGER" do
        it "correctly saves and loads" do
          AllTypeModel.create!(integer_f: 32)
          AllTypeModel.all.last!.integer_f!.should eq(32)
        end
      end

      describe "SHORT" do
        it "correctly saves and loads" do
          AllTypeModel.create!(short_f: 16i16)
          AllTypeModel.all.last!.short_f!.should eq(16i16)
        end
      end

      describe "FLOAT" do
        it "correctly saves and loads" do
          AllTypeModel.create!(float_f: 32f32)
          AllTypeModel.all.last!.float_f!.should eq(32f32)
        end
      end

      describe "DOUBLE" do
        it "correctly saves and loads" do
          AllTypeModel.create!(double_f: 64f64)
          AllTypeModel.all.last!.double_f!.should eq(64f64)
        end
      end

      describe "STRING" do
        it "correctly saves and loads" do
          AllTypeModel.create!(string_f: "string")
          AllTypeModel.all.last!.string_f!.should eq("string")
        end
      end

      describe "VARCHAR" do
        it "correctly saves and loads" do
          AllTypeModel.create!(varchar_f: "string")
          AllTypeModel.all.last!.varchar_f!.should eq("string")
        end
      end

      describe "TEXT" do
        it "correctly saves and loads" do
          AllTypeModel.create!(text_f: "string")
          AllTypeModel.all.last!.text_f!.should eq("string")
        end
      end

      describe Time do
        it "stores to db time converted to UTC" do
          Factory.create_contact
          new_time = Time.local(local_time_zone)
          with_time_zone("Etc/GMT+1") do
            Contact.all.update(created_at: new_time)
            Contact.all.select { [_created_at] }.each_result_set do |rs|
              rs.read(Time).should be_close(new_time, 1.second)
            end
          end
        end

        it "converts values from utc to local" do
          contact = Factory.create_contact
          with_time_zone("Etc/GMT+1") do
            contact.reload.created_at!.should be_close(Time.local(local_time_zone), 1.second)
          end
        end
      end

      describe "TIMESTAMP" do
        it "correctly saves and loads" do
          AllTypeModel.create!(timestamp_f: Time.utc(2016, 2, 15, 10, 20, 30))
          AllTypeModel.all.last!.timestamp_f!.in(UTC).should eq(Time.utc(2016, 2, 15, 10, 20, 30))
        end
      end

      describe "DATETIME" do
        it "correctly saves and loads" do
          AllTypeModel.create!(date_time_f: Time.utc(2016, 2, 15, 10, 20, 30))
          AllTypeModel.all.last!.date_time_f!.in(UTC).should eq(Time.utc(2016, 2, 15, 10, 20, 30))
        end
      end

      describe "DATE" do
        it "correctly saves and loads" do
          AllTypeModel.create!(date_f: Time.utc(2016, 2, 15, 10, 20, 30))
          AllTypeModel.all.last!.date_f!.in(UTC).should eq(Time.utc(2016, 2, 15, 0, 0, 0))
        end
      end

      describe "JSON" do
        it "correctly loads json field" do
          # This checks nillable JSON as well
          c = Factory.create_address(street: "a st.", details: JSON.parse(%(["a", "b", 1])))
          c = Address.find!(c.id)
          c.details.should be_a(JSON::Any)
          c.details![2].as_i.should eq(1)
        end
      end

      postgres_only do
        describe "DECIMAL" do
          it "correctly saves and loads" do
            AllTypeModel.create!(decimal_f: PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [1i16]))
            AllTypeModel.all.last!.decimal_f!.should eq(PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [1i16]))
          end
        end

        describe "OID" do
          it "correctly saves and loads" do
            AllTypeModel.create!(oid_f: 2147483648_u32)
            AllTypeModel.all.last!.oid_f!.should eq(2147483648_u32)
          end
        end

        describe "CHAR" do
          it "correctly saves and loads" do
            AllTypeModel.create!(char_f: "a")
            AllTypeModel.all.last!.char_f!.should eq("a")
          end
        end

        describe "UUID" do
          it "correctly saves and loads" do
            value = UUID.new("7d61d548-124c-4b38-bc05-cfbb88cfd1d1")
            AllTypeModel.create!(uuid_f: value)
            AllTypeModel.all.last!.uuid_f!.should eq(value)
          end
        end

        describe "TIMESTAMPTZ" do
          it "correctly saves and loads" do
            AllTypeModel.create!(timestamptz_f: Time.local(2016, 2, 15, 10, 20, 30, location: BERLIN))
            # NOTE: ATM this is expected behavior
            AllTypeModel.all.last!.timestamptz_f!.in(UTC).should eq(Time.utc(2016, 2, 15, 9, 20, 30))
          end
        end

        describe "BYTEA" do
          it "correctly saves and loads" do
            AllTypeModel.create!(bytea_f: Bytes[65, 114, 116, 105, 99, 108, 101])
            AllTypeModel.all.last!.bytea_f!.should eq(Bytes[65, 114, 116, 105, 99, 108, 101])
          end
        end

        describe "JSONB" do
          it "correctly saves and loads" do
            AllTypeModel.create!(jsonb_f: JSON.parse(%(["a", "b", 1])))
            AllTypeModel.all.last!.jsonb_f!.should eq(JSON.parse(%(["a", "b", 1])))
          end
        end

        describe "XML" do
          it "correctly saves and loads" do
            AllTypeModel.create!(xml_f: "<html></html>")
            AllTypeModel.all.last!.xml_f!.should eq("<html></html>")
          end
        end

        describe "POINT" do
          it "correctly saves and loads" do
            AllTypeModel.create!(point_f: PG::Geo::Point.new(1.2, 3.4))
            AllTypeModel.all.last!.point_f!.should eq(PG::Geo::Point.new(1.2, 3.4))
          end
        end

        describe "LSEG" do
          it "correctly saves and loads" do
            AllTypeModel.create!(lseg_f: PG::Geo::LineSegment.new(1.0, 2.0, 3.0, 4.0))
            AllTypeModel.all.last!.lseg_f!.should eq(PG::Geo::LineSegment.new(1.0, 2.0, 3.0, 4.0))
          end
        end

        describe "PATH" do
          it "correctly saves and loads" do
            path = PG::Geo::Path.new([PG::Geo::Point.new(1.0, 2.0), PG::Geo::Point.new(3.0, 4.0)], closed: true)
            AllTypeModel.create!(path_f: path)
            AllTypeModel.all.last!.path_f!.should eq(path)
          end
        end

        describe "BOX" do
          it "correctly saves and loads" do
            AllTypeModel.create!(box_f: PG::Geo::Box.new(1.0, 2.0, 3.0, 4.0))
            AllTypeModel.all.last!.box_f!.should eq(PG::Geo::Box.new(1.0, 2.0, 3.0, 4.0))
          end
        end
      end

      mysql_only do
        describe "TINYINT" do
          it "correctly saves and loads" do
            AllTypeModel.create!(tinyint_f: 8i8)
            AllTypeModel.all.last!.tinyint_f!.should eq(8i8)
          end
        end

        describe "DECIMAL" do
          it "correctly saves and loads" do
            AllTypeModel.create!(decimal_f: 64f64)
            AllTypeModel.all.last!.decimal_f!.should eq(64f64)
          end
        end

        describe "BLOB" do
          it "correctly saves and loads" do
            AllTypeModel.create!(blob_f: Bytes[65, 114, 116, 105, 99, 108, 101])
            AllTypeModel.all.last!.blob_f!.should eq(Bytes[65, 114, 116, 105, 99, 108, 101])
          end
        end
      end

      context "nillable field" do
        context "passed with ?" do
          it "properly sets field as nillable" do
            typeof(ContactWithNillableName.new.name).should eq(String?)
          end
        end

        context "passed as union" do
          it "properly sets field class as nillable" do
            typeof(Factory.build_contact.created_at).should eq(Time?)
          end
        end
      end

      describe "ENUM (database)" do
        it "properly loads enum" do
          c = Factory.create_contact(name: "sam", age: 18)
          Contact.find!(c.id).gender.should eq("male")
        end

        it "properly search via enum" do
          Factory.create_contact(name: "sam", age: 18, gender: "male")
          Factory.create_contact(name: "Jennifer", age: 18, gender: "female")
          Contact.all.count.should eq(2)
          Contact.where { _gender == "male" }.count.should eq(1)
        end
      end

      context "mismatching data type" do
        it "raises DataTypeMismatch exception" do
          ContactWithNillableName.create({name: nil})
          expected_type = db_specific(mysql: ->{ "String" }, postgres: ->{ "(Slice(UInt8) | String)" })
          expect_raises(::Jennifer::DataTypeMismatch, "Column ContactWithCustomField.name is expected to be a #{expected_type} but got Nil.") do
            ContactWithCustomField.all.last!
          end
        end

        it "raised exception includes query explanation" do
          ContactWithNillableName.create({name: nil})
          expect_raises(::Jennifer::DataTypeMismatch, /[\S\s]*SELECT #{generator.quote_identifier("contacts")}\.\*/i) do
            ContactWithCustomField.all.last!
          end
        end
      end

      context "mismatching data type during loading from hash" do
        it "raises DataTypeCasting exception" do
          c = ContactWithNillableName.create({name: nil})
          Factory.create_address({:contact_id => c.id})
          expect_raises(::Jennifer::DataTypeCasting, "Column Contact.name can't be casted from Nil to it's type - String") do
            Address.all.eager_load(:contact).last!
          end
        end

        it "raised exception includes query explanation" do
          ContactWithNillableName.create({name: nil})
          expect_raises(::Jennifer::DataTypeMismatch, /[\S\s]*SELECT #{generator.quote_identifier("contacts")}\.\*/i) do
            ContactWithCustomField.all.last!
          end
        end
      end

      postgres_only do
        describe Array do
          it "loads nilable array" do
            c = Factory.create_contact({:name => "sam", :age => 18, :gender => "male", :tags => [1, 2]})
            c.tags!.should eq([1, 2])
            Contact.all.first!.tags!.should eq([1, 2])
          end

          it "creates object with array" do
            ContactWithArray.build({tags: [1, 2]}).tags.should eq([1, 2])
          end
        end
      end
    end

    describe "attribute getter" do
      it "provides getters" do
        c = Factory.build_contact(name: "a")
        c.name.should eq("a")
      end
    end

    describe "predicate method" do
      it { AddressWithNilableBool.new({main: true}).main?.should be_true }
      it { AddressWithNilableBool.new({main: false}).main?.should be_false }
      it { AddressWithNilableBool.new({main: nil}).main?.should be_false }
    end

    describe "attribute setter" do
      it "provides setters" do
        c = Factory.build_contact(name: "a")
        c.name = "b"
        c.name.should eq("b")
      end

      it "returns given value" do
        c = Factory.build_contact(name: "a")
        (c.name = "b").should eq("b")
      end

      context "with DBAny" do
        it do
          hash = {:name => "new_name"} of Symbol => Jennifer::DBAny
          c = Factory.build_contact(name: "a")
          c.name = hash[:name]
          c.name.should eq("new_name")
        end
      end

      context "with subset of DBAny" do
        it do
          hash = {:name => "new_name", :age => 12}
          c = Factory.build_contact(name: "a")
          c.name = hash[:name]
          c.name.should eq("new_name")
        end

        context "with wrong type" do
          it do
            hash = {:name => "new_name", :age => 12}
            c = Factory.build_contact(name: "a")
            expect_raises(TypeCastError) do
              c.name = hash[:age]
            end
          end
        end
      end

      context "with stringified value" do
        it "sets nil for empty value" do
          c = Factory.build_contact(user_id: 1)
          c.user_id = ""
          c.user_id.should be_nil
        end

        it "raises an error for blank string if field isn't nullable" do
          c = Factory.build_contact(age: 12)
          expect_raises(NilAssertionError) { c.age = "" }
        end

        postgres_only do
          it "doesn't support PG::Numeric" do
            c = Factory.build_contact
            expect_raises(Jennifer::BaseException, "Type (PG::Numeric | Nil) can't be coerced") { c.ballance = "32" }
          end

          it "doesn't support Array" do
            c = Factory.build_contact(tags: [32])
            expect_raises(Jennifer::BaseException, "Type (Array(Int32) | Nil) can't be coerced") { c.tags = "32" }
          end
        end

        it "supports Int16" do
          record = AllTypeModel.new
          record.short_f = "12"
          record.short_f.should eq(12i16)
        end

        it "supports Int64" do
          record = AllTypeModel.new
          record.bigint_f = "12"
          record.bigint_f.should eq(12i64)
        end

        it "supports Int32" do
          record = AllTypeModel.new
          record.integer_f = "12"
          record.integer_f.should eq(12)
        end

        it "supports Float32" do
          record = AllTypeModel.new
          record.float_f = "12"
          record.float_f.should eq(12.0f32)
        end

        it "supports Float64" do
          record = AllTypeModel.new
          record.double_f = "12"
          record.double_f.should eq(12.0)
        end

        it "supports Bool" do
          record = AllTypeModel.new
          record.bool_f = "true"
          record.bool_f.should be_true
          record.bool_f = "1"
          record.bool_f.should be_true
          record.bool_f = "t"
          record.bool_f.should be_true
          record.bool_f = "f"
          record.bool_f.should be_false
          record.bool_f = "any"
          record.bool_f.should be_false
        end

        it "supports JSON" do
          record = AllTypeModel.new
          record.json_f = %({"a": 1})
          record.json_f.should eq(JSON.parse({a: 1}.to_json))
        end

        it "supports Time" do
          record = AllTypeModel.new
          record.timestamp_f = "2010-12-10 20:10:10"
          record.timestamp_f.should eq(Time.local(2010, 12, 10, 20, 10, 10, location: ::Jennifer::Config.local_time_zone))
        end
      end
    end

    describe "attribute alias" do
      it "provides aliases for the getters and setters" do
        a = Author.build(name1: "an", name2: "author")
        a.name1 = "the"
        a.name1.should eq "the"
      end
    end

    describe "criteria attribute class shortcut" do
      it "adds criteria shortcut for class" do
        c = Contact._name
        c.table.should eq("contacts")
        c.field.should eq("name")
      end
    end

    describe "#initialize" do
      it "reads generated column" do
        Author.create!({:name1 => "First", :name2 => "Last"})
        Author.all.last!.full_name.should eq("First Last")
      end
    end

    describe "#primary" do
      context "default primary field" do
        it "returns id value" do
          c = Factory.build_contact
          c.id = -1
          c.primary.should eq(-1)
        end
      end

      context "custom field" do
        it "returns value of custom primary field" do
          p = Factory.build_passport
          p.enn = "1qaz"
          p.primary.should eq("1qaz")
        end
      end
    end

    describe "#update_columns" do
      context "attribute exists" do
        it "sets attribute if value has proper type" do
          c = Factory.create_contact
          c.update_columns({:name => "123"})
          c.name.should eq("123")
          c = Contact.find!(c.id)
          c.name.should eq("123")
        end

        it "raises exception if value has wrong type" do
          c = Factory.create_contact
          expect_raises(::Jennifer::BaseException) do
            c.update_columns({:name => 123})
          end
        end
      end

      context "no such setter" do
        it "raises exception" do
          c = Factory.build_contact
          expect_raises(::Jennifer::BaseException) do
            c.update_columns({:asd => 123})
          end
        end
      end
    end

    describe "#update_column" do
      context "attribute exists" do
        it "sets attribute if value has proper type" do
          c = Factory.create_contact
          c.update_column(:name, "123")
          c.name.should eq("123")
          c = Contact.find!(c.id)
          c.name.should eq("123")
        end

        it "raises exception if value has wrong type" do
          c = Factory.create_contact
          expect_raises(::Jennifer::BaseException) do
            c.update_column(:name, 123)
          end
        end
      end

      context "no such setter" do
        it "raises exception" do
          c = Factory.build_contact
          expect_raises(::Jennifer::BaseException) do
            c.update_column(:asd, 123)
          end
        end
      end
    end

    describe "#set_attribute" do
      context "when attribute is virtual" do
        it do
          p = Factory.build_profile
          p.set_attribute(:virtual_parent_field, "virtual value")
          p.virtual_parent_field.should eq("virtual value")
        end
      end

      context "when attribute exists" do
        it "sets attribute if value has proper type" do
          c = Factory.build_contact
          c.set_attribute(:name, "123")
          c.name.should eq("123")
        end

        it "raises exception if value has wrong type" do
          c = Factory.build_contact
          expect_raises(::Jennifer::BaseException) do
            c.set_attribute(:name, 123)
          end
        end

        it "marks changed field as modified" do
          c = Factory.build_contact
          c.set_attribute(:name, "asd")
          c.name_changed?.should be_true
        end

        it "supports string coercing" do
          c = Factory.build_contact
          c.set_attribute(:user_id, "12")
          c.user_id.should eq(12)
        end
      end

      context "no such setter" do
        it "raises exception" do
          c = Factory.build_contact
          expect_raises(::Jennifer::BaseException) do
            c.set_attribute(:asd, 123)
          end
        end
      end
    end

    describe "#attribute" do
      context "when attribute is virtual" do
        it "" do
          p = Factory.build_profile
          p.virtual_parent_field = "value"
          p.attribute(:virtual_parent_field).should eq("value")
        end
      end

      it "returns attribute value by given name" do
        c = Factory.build_contact(name: "Jessy")
        c.attribute("name").should eq("Jessy")
        c.attribute(:name).should eq("Jessy")
      end

      it "raises an exception for a missing attribute" do
        c = Factory.build_contact(name: "Jessy")
        expect_raises(::Jennifer::UnknownAttribute) do
          c.attribute("missing")
        end
      end

      it "raises an exception if column name is used instead of field name" do
        a = Author.new({name1: "TheO", name2: "TheExample"})
        a.attribute("name1").should eq("TheO")
        a.attribute(:name2).should eq("TheExample")
        expect_raises(::Jennifer::UnknownAttribute) do
          a.attribute("first_name")
        end
        expect_raises(::Jennifer::UnknownAttribute) do
          a.attribute(:last_name)
        end
      end
    end

    describe "#attribute_before_typecast" do
      it "returns attribute value by given name in db format" do
        address = Factory.build_address(details: JSON.parse(%({"lat":12})))
        address.attribute_before_typecast("details").should eq(%({"lat":12}))
        address.attribute_before_typecast(:details).should eq(%({"lat":12}))
      end

      it "raises exception for a missing attribute" do
        address = Factory.build_address(details: JSON.parse(%({"lat": 12})))
        expect_raises(::Jennifer::UnknownAttribute) do
          address.attribute_before_typecast("missing")
        end
      end

      it "raises an exception if column name is used instead of field name" do
        a = Author.new({name1: "TheO", name2: "TheExample"})
        a.attribute_before_typecast("name1").should eq("TheO")
        a.attribute_before_typecast(:name2).should eq("TheExample")
        expect_raises(::Jennifer::UnknownAttribute) do
          a.attribute_before_typecast("first_name")
        end
        expect_raises(::Jennifer::UnknownAttribute) do
          a.attribute_before_typecast(:last_name)
        end
      end
    end

    describe "#arguments_to_save" do
      it "returns named tuple with correct keys" do
        c = Factory.build_contact
        c.name = "some another name"
        r = c.arguments_to_save
        r.is_a?(NamedTuple).should be_true
        r.keys.should eq({:args, :fields})
      end

      it "returns tuple with empty arguments if no field was changed" do
        r = Factory.build_contact.arguments_to_save
        r[:args].empty?.should be_true
        r[:fields].empty?.should be_true
      end

      it "returns tuple with changed arguments" do
        c = Factory.build_contact
        c.name = "some new name"
        r = c.arguments_to_save
        r[:args].should eq(db_array("some new name"))
        r[:fields].should eq(db_array("name"))
      end

      it "returns aliased columns" do
        a = Author.create(name1: "Fin", name2: "AlAuthor")
        a.name1 = "NotFin"
        r = a.arguments_to_save
        r[:args].should eq(db_array("NotFin"))
        r[:fields].should eq(db_array("first_name"))
      end

      it "uses attributes before typecast" do
        raw_json = %({"asd":1})
        json = JSON.parse(raw_json)
        user = UserWithConverter.new({name: JSON.parse("{}")})
        user.name = json
        user.name.should eq(json)
        user.arguments_to_save[:args].should eq([raw_json])
      end

      it "doesn't include generated columns" do
        author = Author.create(name1: "NoIt", name2: "SNot")
        author.name1 = "1"
        author.full_name = "test"
        author.arguments_to_save[:fields].should eq(%w(first_name))
      end
    end

    describe "#arguments_to_insert" do
      it "returns named tuple with :args and :fields keys" do
        r = Factory.build_profile.arguments_to_insert
        r.is_a?(NamedTuple).should be_true
        r.keys.should eq({:args, :fields})
      end

      it "returns tuple with all fields" do
        r = Factory.build_profile.arguments_to_insert
        r[:fields].should match_array(%w(login contact_id type))
      end

      it "returns tuple with all values" do
        r = Factory.build_profile.arguments_to_insert
        r[:args].should match_array(db_array("some_login", nil, "Profile"))
      end

      it "returns aliased columns" do
        r = Author
          .new({name1: "Prob", name2: "AblyTheLast"})
          .arguments_to_insert
        r[:args].should match_array(db_array("Prob", "AblyTheLast"))
        r[:fields].should match_array(%w(first_name last_name))
      end

      it "includes non autoincrementable primary field" do
        r = NoteWithManualId.new({id: 12, text: "test"}).arguments_to_insert
        r[:args].should match_array(db_array(12, "test", nil, nil))
        r[:fields].should match_array(%w(id text created_at updated_at))
      end

      it "uses attributes before typecast" do
        raw_json = %({"asd":1})
        json = JSON.parse(raw_json)
        user = UserWithConverter.new({name: json})
        user.name.should eq(json)
        user.arguments_to_insert[:args].should eq([raw_json])
      end

      it "doesn't include generated columns" do
        tuple = Author.new({name1: "NoIt", name2: "SNot"}).arguments_to_insert
        tuple[:fields].should eq(%w(first_name last_name))
      end
    end

    describe "#changes_before_typecast" do
      it "includes only changed fields for existing record" do
        author = Author.create(name1: "NoIt", name2: "SNot")
        author.changes_before_typecast.should be_empty

        author.name1 = "test"
        author.full_name = "asd"
        author.changes_before_typecast.should eq({"first_name" => "test"})
      end
    end

    describe "#to_h" do
      it "creates hash with symbol keys" do
        hash = Factory.build_profile(login: "Abdul").to_h
        # NOTE: virtual field isn't included
        hash.keys.should eq(%i(id login contact_id type))
      end

      it "creates hash with symbol keys that does not contain the column names" do
        hash = Author.new({name1: "IsThi", name2: "SFinallyOver"}).to_h
        hash.keys.should eq(%i(id name1 name2 full_name))
      end
    end

    describe "#to_str_h" do
      it "creates hash with string keys" do
        hash = Factory.build_profile(login: "Abdul").to_str_h
        # NOTE: virtual field isn't included
        hash.keys.should eq(%w(id login contact_id type))
      end

      it "creates hash with string keys that does not contain the column names" do
        hash = Author.new({name1: "NoIt", name2: "SNot"}).to_str_h
        hash.keys.should eq(%w(id name1 name2 full_name))
      end
    end

    describe ".primary_auto_incrementable?" do
      it { Note.primary_auto_incrementable?.should be_true }
      it { NoteWithManualId.primary_auto_incrementable?.should be_false }
    end
  end
end
