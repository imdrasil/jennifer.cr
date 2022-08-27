require "../spec_helper"

describe Jennifer::Relation::IPolymorphicBelongsTo do
  example_class = PolymorphicNote::NotableRelation
  relation_name = "notable"
  note_class = PolymorphicNote
  contact_class = ContactForPolymorphicNote
  example_relation = example_class.new(relation_name, nil, nil, nil)

  describe "#foreign_type" do
    context "without specified foreign type" do
      it do
        example_class.new(relation_name, nil, nil, nil).foreign_type.should eq("notable_type")
      end
    end

    context "with specified foreign type" do
      it do
        example_class.new(relation_name, nil, nil, "specific_type").foreign_type.should eq("specific_type")
      end
    end
  end

  describe "#foreign_field" do
    context "without specified foreign field" do
      it do
        example_class.new(relation_name, nil, nil, nil).foreign_field.should eq("notable_id")
      end
    end

    context "with specified foreign field" do
      it do
        example_class.new(relation_name, "specific_type", nil, nil).foreign_field.should eq("specific_type")
      end
    end
  end

  describe "#primary_field" do
    context "without specified primary field" do
      it do
        example_class.new(relation_name, nil, nil, nil).primary_field.should eq("id")
      end
    end

    context "with specified primary field" do
      it do
        example_class.new(relation_name, nil, "specific_field", nil).primary_field.should eq("specific_field")
      end
    end
  end

  describe "#condition_clause" do
    context "without custom query" do
      pending "uses attributes before typecast for foreign type"

      describe "for specific id" do
        it do
          condition = example_relation.condition_clause(1, contact_class.to_s)
          condition.should eq(contact_class.c(:id, relation_name) == 1)
        end
      end

      describe "for array of ids" do
        it do
          condition = example_relation.condition_clause([1, 2, 3], contact_class.to_s)
          condition.should eq(contact_class.c(:id, relation_name).in([1, 2, 3]))
        end
      end
    end
  end

  describe "#query" do
    context "with nil polymorphic type" do
      it do
        example_relation.query(1, nil).do_nothing?.should be_true
      end
    end

    context "with valid polymorphic type" do
      it do
        contact = Factory.create_contact
        example_relation.query(contact.id, contact_class.to_s).count.should eq(1)
      end
    end
  end

  describe "#build" do
    context "with valid polymorphic type" do
      it do
        p = example_relation.build({"name" => "test"} of String => Jennifer::DBAny, contact_class.to_s)
        p.is_a?(ContactForPolymorphicNote).should be_true
      end
    end

    context "with invalid polymorphic type" do
      it do
        expect_raises(Jennifer::BaseException) do
          example_relation.build({} of String => Jennifer::DBAny, "Contact")
        end
      end
    end

    describe "alternative class" do
      it do
        u = example_relation.build({} of String => Jennifer::DBAny, "User")
        u.is_a?(User).should be_true
      end
    end
  end

  describe "#create!" do
    context "with valid polymorphic type" do
      it do
        c = example_relation.create!({"name" => "login"} of String => Jennifer::DBAny, contact_class.to_s)
        c.is_a?(ContactForPolymorphicNote).should be_true
        c.persisted?.should be_true
      end

      describe "alternative class" do
        it do
          u = example_relation.build(Factory.build_user.to_str_h, "User")
          u.is_a?(User).should be_true
          u.persisted?.should be_true
        end
      end
    end

    context "with invalid polymorphic type" do
      it do
        expect_raises(Jennifer::BaseException) do
          example_relation.create!({} of String => Jennifer::DBAny, "Contact")
        end
      end
    end

    context "with invalid model options" do
      it do
        expect_raises(Jennifer::RecordInvalid) do
          example_relation.create!({} of String => Jennifer::DBAny, "User")
        end
      end
    end
  end

  describe "#load" do
    context "with valid polymorphic type" do
      context "with blank foreign field" do
        it do
          example_relation.load(nil, "User").should be_nil
        end
      end

      it do
        u = Factory.create_user([:with_valid_password])
        example_relation.load(u.id, "User").as(User).id.should eq(u.id)
      end
    end

    context "with invalid polymorphic type" do
      it do
        expect_raises(Jennifer::BaseException) do
          example_relation.load(1, "Contact")
        end
      end
    end
  end

  describe "#destroy" do
    context "with valid polymorphic type" do
      it "destroys record" do
        c = Factory.create_contact
        n = note_class.new({text: "test", notable_type: contact_class.to_s, notable_id: c.id})

        count = contact_class.all.count
        example_relation.destroy(n)
        contact_class.find(c.id).should be_nil
        contact_class.all.count.should eq(count - 1)
      end

      it "uses attributes before typecast for foreign and type fields" do
        c = Factory.create_contact
        n = PolymorphicNoteWithConverter.new({notable_type: contact_class.to_s, notable_id: c.id})
        n.notable_id.should eq("Int64: #{c.id}")
        n.notable_type.should eq("String: #{contact_class}")

        count = contact_class.all.count
        PolymorphicNoteWithConverter::NotableRelation.new(relation_name, nil, nil, nil).destroy(n)
        contact_class.find(c.id).should be_nil
        contact_class.all.count.should eq(count - 1)
      end

      context "with blank foreign field" do
        it do
          n = note_class.new({text: "test"})
          example_relation.destroy(n).should be_nil
        end
      end
    end

    context "with invalid polymorphic type" do
      it do
        n = note_class.new({text: "test", notable_type: "Contact", notable_id: 1})
        expect_raises(Jennifer::BaseException) do
          example_relation.destroy(n)
        end
      end
    end
  end

  describe "#insert" do
    context "with hash" do
      it do
        n = note_class.find!(Factory.create_note.id)
        opts = {
          "name"         => "login",
          "notable_type" => "ContactForPolymorphicNote",
        } of String => Jennifer::DBAny
        example_relation.insert(n, opts).as(ContactForPolymorphicNote)
        p = n.notable.as(ContactForPolymorphicNote)
        n.notable_id.should eq(p.id)
        n.notable_type.should eq(contact_class.to_s)
      end

      pending "uses attributes before typecast for foreign fields"

      describe "alternative class" do
        it do
          n = PolymorphicNote.find!(Factory.create_note.id)
          opts = {
            "name"         => "name",
            "age"          => 42,
            "gender"       => "male",
            "notable_type" => "ContactForPolymorphicNote",
          } of String => Jennifer::DBAny
          PolymorphicNote.notable_relation.insert(n, opts)
          p = n.notable.as(ContactForPolymorphicNote)
          n.notable_id.should eq(p.id)
          n.notable_type.should eq("ContactForPolymorphicNote")
        end
      end
    end

    context "with object" do
      it do
        n = note_class.find!(Factory.create_note.id)
        c = contact_class.create!(name: "login")
        example_relation.insert(n, c)
        n.notable_id.should eq(c.id)
        n.notable_type.should eq(contact_class.to_s)
      end

      it "raises exception if object is already assigned" do
        c1 = contact_class.find!(Factory.create_contact.id)
        c2 = contact_class.find!(Factory.create_contact.id)
        n = note_class.new({text: "some text"})
        n = c2.add_notes(n)[0]
        expect_raises(Jennifer::BaseException) do
          example_relation.insert(n, c1)
        end
      end

      pending "uses attributes before typecast for foreign fields"

      describe "alternative class" do
        it do
          n = note_class.find!(Factory.create_note.id)
          c = contact_class.find!(Factory.create_contact.id)
          note_class.notable_relation.insert(n, c)

          n.notable_id.should eq(c.id)
          n.notable_type.should eq(c.class.to_s)
        end
      end
    end
  end

  describe "#remove" do
    it do
      c = contact_class.find!(Factory.create_contact.id)
      n = c.add_notes(note_class.new({text: "some text"}))[0]

      example_relation.remove(n)
      n.reload
      n.notable_type.should be_nil
      n.notable_id.should be_nil
    end

    describe "alternative class" do
      it do
        n = note_class.create!({text: "some_text", notable_id: 1, notable_type: "User"})

        example_relation.remove(n)
        n.reload
        n.notable_type.should be_nil
        n.notable_id.should be_nil
      end
    end
  end
end
