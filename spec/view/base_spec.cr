require "../spec_helper"

describe Jennifer::View::Base do
  describe "#inspect" do
    it do
      Factory.create_contact(gender: "male")
      view = MaleContact.all.first!
      view.inspect.should eq("#<MaleContact:0x#{view.object_id.to_s(16)} id: #{view.id}, name: \"Deepthi\", " \
                             "gender: \"male\", age: 28, created_at: #{view.created_at.inspect}>")
    end
  end

  describe ".primary" do
    it "return criteria with primary key" do
      c = MaleContact.primary
      c.table.should eq("male_contacts")
      c.field.should eq("id")
    end
  end

  describe ".primary_field_name" do
    it "returns name of primary field" do
      MaleContact.primary_field_name.should eq("id")
    end
  end

  describe ".view_name" do
    it "loads from class name automatically" do
      FemaleContact.view_name.should eq("female_contacts")
    end

    it "returns specified name" do
      StrictBrokenMaleContact.view_name.should eq("male_contacts")
    end
  end

  describe ".c" do
    it "creates criteria with given name" do
      c = FemaleContact.c("some_field")
      c.is_a?(Jennifer::QueryBuilder::Criteria)
      c.field.should eq("some_field")
      c.table.should eq("female_contacts")
      c.relation.should be_nil
    end

    it "creates criteria with given name and relation" do
      c = FemaleContact.c("some_field", "some_relation")
      c.is_a?(Jennifer::QueryBuilder::Criteria)
      c.field.should eq("some_field")
      c.table.should eq("female_contacts")
      c.relation.should eq("some_relation")
    end
  end

  describe "%scope" do
    context "with block" do
      it "executes in query context" do
        sql_generator.select(MaleContact.all.older(18))
          .should match(/#{reg_quote_identifier("male_contacts.age")} >/)
      end

      context "without arguemnt" do
        it "is accessible from query object" do
          MaleContact.all.main.as_sql.should match(/#{reg_quote_identifier("male_contacts.age")} </)
        end
      end

      context "with argument" do
        it "is accessible from query object" do
          MaleContact.all.older(12).as_sql.should match(/#{reg_quote_identifier("male_contacts.age")} >=/)
        end
      end

      context "same names" do
        it "is accessible from query object" do
          MaleContact.all.main.as_sql.should match(/#{reg_quote_identifier("male_contacts.age")} </)
          Contact.all.main.as_sql.should match(/#{reg_quote_identifier("contacts.age")} >/)
        end
      end

      it "is chainable" do
        Factory.create_contact(age: 15)
        Factory.create_contact(age: 19)
        Factory.create_contact(age: 20, name: "Johny")
        MaleContact.all.johny.older(14).count.should eq(1)
      end
    end

    context "with query object class" do
      it "executes in class context" do
        sql_generator.select(MaleContact.johny).should match(/#{reg_quote_identifier("name")} =/)
      end

      context "without arguemnt" do
        it "is accessible from query object" do
          MaleContact.johny.as_sql.should match(/#{reg_quote_identifier("male_contacts.name")} =/)
        end
      end

      context "with argument" do
        it "is accessible from query object" do
          MaleContact.older(12).as_sql.should match(/#{reg_quote_identifier("male_contacts.age")} >=/)
        end
      end

      it "is chainable" do
        Factory.create_contact(name: "Johny", age: 19)
        Factory.create_contact(name: "Johny", age: 21)
        MaleContact.johny.older(20).count.should eq(1)
      end
    end
  end

  describe ".relations" do
    pending "add" do
      # NOTE: now views don't support relations
    end
  end

  describe ".where" do
    it "returns query" do
      res = MaleContact.where { _id == 1 }
      res.should be_a(::Jennifer::QueryBuilder::ModelQuery(MaleContact))
    end
  end

  describe ".all" do
    it "returns empty query" do
      MaleContact.all.empty?.should be_true
    end
  end

  describe ".views" do
    it "returns all model classes" do
      views = Jennifer::View::Base.views
      views.is_a?(Array).should be_true
      # I tired from modifing this each time new view is added
      (views.size > 0).should be_true
    end

    it "doesn't include Materialized class" do
      Jennifer::View::Base.views.includes?(Jennifer::View::Materialized).should be_false
    end
  end

  describe ".build" do
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
          error_message = "Column StrictBrokenMaleContact.name can't be casted from Nil to it's type - String"
          expect_raises(Jennifer::BaseException, error_message) do
            StrictBrokenMaleContact.build({} of String => Jennifer::DBAny)
          end
        end
      end
    end
  end

  describe "#to_json" do
    it "includes all fields by default" do
      Factory.create_contact(name: "Johny", age: 19)
      record = MaleContact.all.first!
      record.to_json.should eq({
        id:         record.id,
        name:       record.name,
        gender:     record.gender,
        age:        record.age,
        created_at: record.created_at,
      }.to_json)
    end

    it "allows to specify *only* argument solely" do
      Factory.create_contact(name: "Johny", age: 19)
      record = MaleContact.all.first!
      record.to_json(%w[id]).should eq(%({"id":#{record.id}}))
    end

    it "allows to specify *except* argument solely" do
      Factory.create_contact(name: "Johny", age: 19)
      record = MaleContact.all.first!
      record.to_json(except: %w[id]).should eq({
        name:       record.name,
        gender:     record.gender,
        age:        record.age,
        created_at: record.created_at,
      }.to_json)
    end

    context "with block" do
      it "allows to extend json using block" do
        Factory.create_contact(name: "Johny", age: 19)
        executed = false
        record = MaleContact.all.first!
        record.to_json do |json, obj|
          executed = true
          obj.should eq(record)
          json.field "custom", "value"
        end.should eq({
          id:         record.id,
          name:       record.name,
          gender:     record.gender,
          age:        record.age,
          created_at: record.created_at,
          custom:     "value",
        }.to_json)
        executed.should be_true
      end

      it "respects :only option" do
        Factory.create_contact(name: "Johny", age: 19)
        record = MaleContact.all.first!
        record.to_json(%w[id]) do |json|
          json.field "custom", "value"
        end.should eq({id: record.id, custom: "value"}.to_json)
      end

      it "respects :except option" do
        Factory.create_contact(name: "Johny", age: 19)
        record = MaleContact.all.first!
        record.to_json(except: %w[id]) do |json|
          json.field "custom", "value"
        end.should eq({
          name:       record.name,
          gender:     record.gender,
          age:        record.age,
          created_at: record.created_at,
          custom:     "value",
        }.to_json)
      end
    end
  end
end
