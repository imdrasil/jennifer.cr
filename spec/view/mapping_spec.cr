require "../spec_helper"

class ViewWithArray < Jennifer::View::Base
  view_name "contacts"

  mapping({
    id:   Primary64,
    tags: Array(Int32),
  }, false)
end

class ViewWithBool < Jennifer::View::Base
  mapping({
    id:   Primary64,
    bool: Bool,
  }, false)
end

class ViewWithNilableBool < Jennifer::View::Base
  mapping({
    id:   Primary64,
    bool: Bool?,
  }, false)
end

describe Jennifer::View::Mapping do
  describe "#reload" do
    it "assign all values from db to existing object" do
      c1 = Factory.create_contact
      c2 = MaleContact.all.first!
      c1.age = 55
      c1.save!
      c2.reload
      c2.age.should eq(55)
    end

    it "correctly assigns mapped column names" do
      b = Book.create(
        name: "RememberSammieJenkins",
        version: 600,
        publisher: "NolanBros",
        pages: 394
      )

      p = PrintPublication.all.first!
      b.name = "RememberSammyJenkins"
      b.version = 601
      b.pages = 397
      b.save!
      p.reload
      p.title.should eq "RememberSammyJenkins"
      p.v.should eq 601
      p.pages.should eq 397
    end
  end

  describe "%mapping" do
    describe ".columns_tuple" do
      it "returns named tuple with column metadata" do
        metadata = MaleContact.columns_tuple
        metadata.is_a?(NamedTuple).should be_true
        metadata[:id].is_a?(NamedTuple).should be_true
        metadata[:id][:type].should eq(Int64?)
        metadata[:id][:parsed_type].should eq("::Union(Int64, ::Nil)")
      end

      it "correctly maps column aliases" do
        metadata = PrintPublication.columns_tuple
        metadata.is_a?(NamedTuple).should be_true
        metadata[:v].is_a?(NamedTuple).should be_true
        metadata[:v][:type].should eq Int32
        metadata[:v][:parsed_type].should eq "Int32"
      end
    end

    context "columns metadata" do
      it "sets constant" do
        MaleContact::COLUMNS_METADATA.is_a?(NamedTuple).should be_true
      end

      it "sets primary to true for Primary32 type" do
        MaleContact::COLUMNS_METADATA[:id][:primary].should be_true
      end

      it "sets primary for Primary64" do
        StrictMaleContactWithExtraField::COLUMNS_METADATA[:id][:primary].should be_true
      end
    end

    describe "#initialize" do
      describe "from result set" do
        it "creates object" do
          Factory.create_contact(gender: "male", name: "John")
          count = 0
          MaleContact.all.each_result_set do |rs|
            record = MaleContact.new(rs)
            record.gender.should eq("male")
            record.name.should eq("John")
            count += 1
          end
          count.should eq(1)
        end
      end

      describe "from result set with mapped columns" do
        it "creates the object" do
          Article.create(
            name: "ItsNoFunTillSomeoneDies",
            version: 11235,
            publisher: "HarryManback",
            size: 10000
          )

          count = 0
          PrintPublication.all.each_result_set do |rs|
            record = PrintPublication.new(rs)
            record.title.should eq "ItsNoFunTillSomeoneDies"
            record.v.should eq 11235
            record.pages.should eq 10000
            record.type.should eq "Article"
            count += 1
          end

          count.should eq 1
        end
      end

      describe "from hash" do
        it "creates object" do
          MaleContact.new({"name" => "Deepthi", "age" => 18, "gender" => "female"})
          MaleContact.new({:name => "Deepthi", :age => 18, :gender => "female"})
        end

        it "maps aliased columns" do
          PrintPublication.new({
            "title"     => "OverthinkingOveranalying",
            "v"         => 4,
            "publisher" => "SeparatesTheBodyFromTheMind",
            "pages"     => 924,
            "type"      => "Book",
          })
          PrintPublication.new({
            :title     => "OverthinkingOveranalying",
            :v         => 4,
            :publisher => "SeparatesTheBodyFromTheMind",
            :pages     => 924,
            :type      => "Book",
          })
        end
      end

      describe "from named tuple" do
        it "creates object" do
          MaleContact.new({name: "Deepthi", age: 18, gender: "female"})
        end

        it "maps aliased columns" do
          PrintPublication.new({
            title:     "AndTheWind",
            v:         2,
            publisher: "ShallScreamMyName",
            pages:     9,
            type:      "Article",
          })
        end
      end
    end

    describe ".field_count" do
      it "returns correct number of model fields" do
        MaleContact.field_count.should eq(5)
      end

      it "only counts aliased columns once" do
        PrintPublication.field_count.should eq 7
      end
    end

    context "data types" do
      context "mismatching data type" do
        it "raises DataTypeMismatch exception" do
          Factory.create_contact(description: nil)
          expected_type = db_specific(mysql: ->{ "String" }, postgres: ->{ "(Slice(UInt8) | String)" })
          error_message = "Column MaleContactWithDescription.description is expected to be a #{expected_type} but got Nil."
          expect_raises(::Jennifer::DataTypeMismatch, error_message) do
            MaleContactWithDescription.all.last!
          end
        end
      end

      context "mismatching data type during loading from hash" do
        it "raises DataTypeCasting exception" do
          expect_raises(::Jennifer::DataTypeCasting, "Column MaleContact.name can't be casted from Nil to it's type - String") do
            MaleContact.new({gender: nil})
          end
        end
      end

      describe "user-defined mapping types" do
        it "is accessible if defined in parent class" do
          FemaleContact::COLUMNS_METADATA[:name].should eq({type: String, column: "name", null: true, parsed_type: "String?"})
        end

        pending "allows to add extra options" do
        end

        pending "allows to override options" do
        end
      end

      describe JSON::Any do
        pending "properly loads json field" do
          # This checks nillable JSON as well
          # c = Factory.create_address(street: "a st.", details: JSON.parse(%(["a", "b", 1])))
          # c = Address.find!(c.id)
          # c.details.should be_a(JSON::Any)
          # c.details![2].as_i.should eq(1)
        end
      end

      describe Time do
        it "stores to db time converted to UTC" do
          Factory.create_contact
          new_time = Time.local(local_time_zone)

          with_time_zone("Etc/GMT+1") do
            Contact.all.update(created_at: new_time)
            MaleContact.all.select { [_created_at] }.each_result_set do |rs|
              rs.read(Time).should be_close(new_time, 1.second)
            end
          end
        end

        it "converts values from utc to local" do
          Factory.create_contact
          with_time_zone("Etc/GMT+1") do
            MaleContact.all.first!.created_at!.should be_close(Time.local(local_time_zone), 2.seconds)
          end
        end
      end

      describe Bool do
        it { ViewWithBool.new({"bool" => false}).bool.should eq(false) }
        it { ViewWithBool.new({"bool" => false}).bool?.should eq(false) }
        it { ViewWithNilableBool.new({"bool" => false}).bool.should eq(false) }
        it { ViewWithNilableBool.new({"bool" => false}).bool?.should eq(false) }
      end

      postgres_only do
        describe Array do
          it do
            ViewWithArray.new({"tags" => [1, 2]}).tags.should eq([1, 2])
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

        it "provides getters for aliased columns" do
          pb = PrintPublication.new({
            title:     "PrintPublicationsAreTheFutureOfTheInternet",
            v:         71,
            publisher: "AVerySeriousProvider",
            pages:     13,
            type:      "Article",
          })

          pb.title.should eq "PrintPublicationsAreTheFutureOfTheInternet"
          pb.v.should eq 71
        end
      end

      describe "attribute setter" do
        it "provides setters" do
          c = Factory.build_male_contact(name: "a")
          c.name = "b"
          c.name.should eq("b")
        end

        it "provides setters for aliased columns" do
          pb = PrintPublication.new({
            title:     "PrintPublicationsAreTheFutureOfTheInternet",
            v:         71,
            publisher: "AVerySeriousProvider",
            pages:     13,
            type:      "Article",
          })

          pb.title = "ProbablyALittleOverexaggerated"
          pb.title.should eq "ProbablyALittleOverexaggerated"
          pb.v.should eq 71
        end
      end

      describe "._{{attribute}}" do
        c = MaleContact._name
        pb = PrintPublication._v
        it { c.table.should eq(MaleContact.view_name) }
        it { c.field.should eq("name") }
        it { pb.table.should eq(PrintPublication.view_name) }
        it { pb.field.should eq "version" }
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

      it "returns attribute values of mapped fields" do
        pb = PrintPublication.new({
          title:     "PrintPublicationsAreTheFutureOfTheInternet",
          v:         71,
          publisher: "AVerySeriousProvider",
          pages:     13,
          type:      "Article",
        })
        pb.attribute("v").should eq 71
        pb.attribute(:v).should eq 71
      end
    end

    describe "#to_h" do
      it "creates hash with symbol keys" do
        Factory.create_contact(age: 19, gender: "male")
        MaleContact.all.first!.to_h[:age].should eq(19)
      end

      it "creates a hash with symbol keys and mapped columns" do
        Article.create(
          name: "PrintPublicationsAreTheFutureOfTheInternet",
          version: 71,
          publisher: "AVerySeriousProvider",
          pages: 13,
        )
        PrintPublication.all.first!.to_h[:v].should eq 71
      end
    end

    describe "#to_str_h" do
      it "creates hash with string keys" do
        Factory.create_contact(age: 19, gender: "male")
        MaleContact.all.first!.to_str_h["age"].should eq(19)
      end

      it "creates a hash with string keys and mapped columns" do
        Article.create(
          name: "PrintPublicationsAreTheFutureOfTheInternet",
          version: 71,
          publisher: "AVerySeriousProvider",
          pages: 13,
        )
        PrintPublication.all.first!.to_str_h["v"].should eq 71
      end
    end

    describe "#attribute" do
      it "returns attribute value by given name" do
        c = MaleContact.build(Factory.build_contact(name: "Jessy").to_h)

        c.attribute("name").should eq("Jessy")
        c.attribute(:name).should eq("Jessy")
      end

      # TODO somehow enable
      pending "returns attribute values of mapped fields by the given name" do
        # TODO this does not work since Article#name is mapped to Article#title
        # and PrintPublication does not know about this mapping
        pb = PrintPublication.new(
          Article.new({
            name:      "PrintPublicationsAreTheFutureOfTheInternet",
            version:   71,
            publisher: "AVerySeriousProvider",
            pages:     13,
          }).to_h
        )
        pb.attribute("v").should eq 71
        pb.attribute(:v).should eq 71
      end
    end
  end

  describe ".field_names" do
    it "returns array of defined fields" do
      MaleContact.field_names.should eq(%w(id name gender age created_at))
    end

    it "only returns the actual field names of aliased columns" do
      PrintPublication.field_names.should eq %w(id title v publisher pages url type)
    end
  end
end
