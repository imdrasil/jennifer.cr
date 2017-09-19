require "../spec_helper"

describe Jennifer::View::ExperimentalMapping do
  describe "#reload" do
    it "assign all values from db to existing object" do
      c1 = Factory.create_contact
      c2 = MaleContact.all.first!
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
      executed = false
      c1 = Factory.create_contact(ballance: ballance)
      MaleContact.all.where { _id == c1.id }.each_result_set do |rs|
        executed = true
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
      executed.should be_true
    end

    context "strict mapping" do
      it "raises exception if not all fields are described" do
        Factory.create_contact
        executed = false
        expect_raises(::Jennifer::BaseException) do
          StrictMaleContactWithExtraField.all.each_result_set do |rs|
            executed = true
            begin
              StrictMaleContactWithExtraField.build(rs)
            ensure
              rs.read_to_end
            end
          end
        end
        executed.should be_true
      end
    end

    context "with hash" do
      context "strict mapping" do
        it "raises exception if some field can't be casted" do
          error_message = "Column StrinctBrokenMaleContact.name can't be casted from Nil to it's type - String"
          expect_raises(Jennifer::BaseException, error_message) do
            StrinctBrokenMaleContact.build({} of String => Jennifer::DBAny)
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
          MaleContact.build({"name" => "Deepthi", "age" => 18, "gender" => "female"})
          MaleContact.build({:name => "Deepthi", :age => 18, :gender => "female"})
        end
      end

      context "from named tuple" do
        it "properly creates object" do
          MaleContact.build({name: "Deepthi", age: 18, gender: "female"})
        end
      end

      context "model has only id field" do
        pending "creates succesfully without arguments" do
          # id = OneFieldModel.create.id
          # OneFieldModel.find!(id).id.should eq(id)
        end
      end
    end

    describe "::field_count" do
      it "returns correct number of model fields" do
        MaleContact.field_count.should eq(4)
      end
    end

    context "data types" do
      context "mismatching data type" do
        it "raises DataTypeMismatch exception" do
          Factory.create_contact(description: nil)
          error_message = "Column MaleContactWithDescription.description is expected to be a String but got Nil."
          expect_raises(::Jennifer::DataTypeMismatch, error_message) do
            MaleContactWithDescription.all.last!
          end
        end
      end

      context "mismatching data type during loading from hash" do
        it "raises DataTypeCasting exception" do
          expect_raises(::Jennifer::DataTypeCasting, "Column MaleContact.name can't be casted from Nil to it's type - String") do
            MaleContact.build({gender: nil})
          end
        end
      end
    end

    describe "%__field_declaration" do
      describe "attribute getter" do
        it "provides getters" do
          c = Factory.build_male_contact(name: "a")
          c.name.should eq("a")
        end
      end

      describe "attribute setter" do
        it "provides setters" do
          c = Factory.build_male_contact(name: "a")
          c.name = "b"
          c.name.should eq("b")
        end
      end
    end

    describe "criteria attribute class shortcut" do
      it "adds criteria shortcut for class" do
        c = MaleContact._name
        c.table.should eq("male_contacts")
        c.field.should eq("name")
      end
    end

    describe "#primary" do
      context "defaul primary field" do
        it "returns id valud" do
          c = Factory.build_male_contact
          c.id = -1
          c.primary.should eq(-1)
        end
      end
    end

    describe "#attribute" do
      it "returns attribute value by given name" do
        c = Factory.build_male_contact(name: "Jessy")
        c.attribute("name").should eq("Jessy")
        c.attribute(:name).should eq("Jessy")
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
end
