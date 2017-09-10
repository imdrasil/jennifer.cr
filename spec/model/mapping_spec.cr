require "../spec_helper"

describe Jennifer::Model::Mapping do
  describe "#reload" do
    it "assign all values from db to existing object" do
      c1 = Factory.create_contact
      c2 = Contact.all.first!
      c1.age = 55
      c1.save!
      c2.reload
      c2.age.should eq(55)
    end
  end

  describe "#_extract_attributes" do
    it "returns tuple with values" do
      ballance = postgres_only do
        PG::Numeric.new(1i16, 0i16, 0i16, 0i16, [1i16])
      end
      mysql_only do
        10f64
      end
      c1 = Factory.create_contact(ballance: ballance)
      Contact.all.where { _id == c1.id }.each_result_set do |rs|
        res = c1._extract_attributes(rs)
        res.is_a?(Tuple).should be_true
        res[0].should eq(c1.id)
        res[1].should eq("Deepthi")
        res[2].should eq(ballance)
        res[3].should eq(28)
        res[4].should eq("male")
        res[6].is_a?(Time).should be_true
        res[7].is_a?(Time).should be_true
      end
    end

    it "allows one field models" do
      model = OneFieldModel.create
      is_executed = false
      OneFieldModel.where { _id == model.id }.each_result_set do |rs|
        res = model._extract_attributes(rs)
        res.should eq(model.id)
        is_executed = true
      end
      is_executed.should be_true
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

      it "result set has no some field" do
        o = OneFieldModel.create({} of String => Jennifer::DBAny)
        error_message = "Column OneFieldModelWithExtraArgument#missing_field hasn't been found in the result set."
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

    context "with hash" do
      context "strict mapping" do
        it "raises exception if some field can't be casted" do
          error_message = "Column OneFieldModelWithExtraArgument.missing_field can't be casted from Nil to it's type - String"
          expect_raises(Jennifer::BaseException, error_message) do
            OneFieldModelWithExtraArgument.build({} of String => Jennifer::DBAny)
          end
        end
      end
    end
  end

  describe "%mapping" do
    describe "#initialize" do
      context "from result set" do
        pending "properly creates object" do
        end
      end

      context "from hash" do
        it "properly creates object" do
          Contact.build({"name" => "Deepthi", "age" => 18, "gender" => "female"})
          Contact.build({:name => "Deepthi", :age => 18, :gender => "female"})
        end
      end

      context "from named tuple" do
        it "properly creates object" do
          Contact.build({name: "Deepthi", age: 18, gender: "female"})
        end
      end

      context "model has only id field" do
        it "creates succesfully without arguments" do
          id = OneFieldModel.create.id
          OneFieldModel.find!(id).id.should eq(id)
        end
      end
    end

    describe "::field_count" do
      it "returns correct number of model fields" do
        postgres_only do
          Contact.field_count.should eq(9)
        end
        mysql_only do
          Contact.field_count.should eq(8)
        end
      end
    end

    context "data types" do
      describe "JSON" do
        it "properly loads json field" do
          c = Factory.create_address(street: "a st.", details: JSON.parse(%(["a", "b", 1])))
          c = Address.find!(c.id)
          c.details.should be_a(JSON::Any)
          c.details![2].as_i.should eq(1)
        end
      end

      describe "ENUM" do
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

      describe "TIMESTAMP" do
        it "properly saves and loads" do
          c1 = Factory.create_contact(name: "Sam", age: 18)
          time = Time.new(2001, 12, 23, 23, 58, 59)
          c1.created_at = time
          c1.save
          c2 = Contact.find!(c1.id)
          c2.created_at.should eq(time)
        end
      end

      context "mismatching data type" do
        it "raises DataTypeMismatch exception" do
          ContactWithNillableName.create({name: nil})
          expect_raises(::Jennifer::DataTypeMismatch, "Column ContactWithCustomField.name is expected to be a String but got Nil.") do
            ContactWithCustomField.all.last!
          end
        end
      end

      context "mismatching data type during loading from hash" do
        it "raises DataTypeCasting exception" do
          c = ContactWithNillableName.create({name: nil})
          Factory.create_address({:contact_id => c.id})
          expect_raises(::Jennifer::DataTypeCasting, "Column Contact.name can't be casted from Nil to it's type - String") do
            Address.all.includes(:contact).last!
          end
        end
      end

      postgres_only do
        describe "Array" do
          it "properly load array" do
            c = Factory.create_contact({:name => "sam", :age => 18, :gender => "male", :tags => [1, 2]})
            c.tags!.should eq([1, 2])
            Contact.all.first!.tags!.should eq([1, 2])
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

    describe "attribute setter" do
      it "provides setters" do
        c = Factory.build_contact(name: "a")
        c.name = "b"
        c.name.should eq("b")
      end
    end

    describe "criteria attribute class shortcut" do
      it "adds criteria shortcut for class" do
        c = Contact._name
        c.table.should eq("contacts")
        c.field.should eq("name")
      end
    end

    describe "#primary" do
      context "defaul primary field" do
        it "returns id valud" do
          c = Factory.build_contact
          c.id = -1
          c.primary.should eq(-1)
        end
      end

      context "custom field" do
        it "returns valud of custom primary field" do
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

        it "raises exeption if value has wrong type" do
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

        it "raises exeption if value has wrong type" do
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
      context "attribute exists" do
        it "sets attribute if value has proper type" do
          c = Factory.build_contact
          c.set_attribute(:name, "123")
          c.name.should eq("123")
        end

        it "raises exeption if value has wrong type" do
          c = Factory.build_contact
          expect_raises(::Jennifer::BaseException) do
            c.set_attribute(:name, 123)
          end
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
      it "returns attribute value by given name" do
        c = Factory.build_contact(name: "Jessy")
        c.attribute("name").should eq("Jessy")
        c.attribute(:name).should eq("Jessy")
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
    end

    describe "#to_h" do
      pending "creates hash with symbol keys" do
      end
    end

    describe "#attribute_hash" do
      pending "creates hash with attributes" do
      end
    end
  end

  describe "%with_timestamps" do
    it "adds callbacks" do
      Contact::BEFORE_CREATE_CALLBACKS.should contain("__update_created_at")
      Contact::BEFORE_SAVE_CALLBACKS.should contain("__update_updated_at")
    end
  end

  describe "#__update_created_at" do
    it "updates created_at field" do
      c = Factory.build_contact
      c.created_at.should be_nil
      c.__update_created_at
      c.created_at!.should_not be_nil
      ((c.created_at! - Time.now).total_seconds < 1).should be_true
    end
  end

  describe "#__update_updated_at" do
    it "updates updated_at field" do
      c = Factory.build_contact
      c.updated_at.should be_nil
      c.__update_updated_at
      c.updated_at!.should_not be_nil
      ((c.updated_at! - Time.now).total_seconds < 1).should be_true
    end
  end
end
