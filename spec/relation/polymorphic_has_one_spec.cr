require "../spec_helper"

describe Jennifer::Relation::PolymorphicHasOne do
  example_class = Jennifer::Relation::PolymorphicHasOne(NoteWithCallback, ProfileWithOneNote)
  relation_name = "note"
  note = NoteWithCallback
  profile = ProfileWithOneNote
  query = NoteWithCallback.all
  example_relation = example_class.new(relation_name, nil, nil, query, nil, :notable)

  describe "#foreign_type" do
    context "without specified foreign type" do
      it do
        example_class.new(relation_name, nil, nil, NoteWithCallback.all, nil, :notable).foreign_type.should eq("notable_type")
      end
    end

    context "with specified foreign type" do
      it do
        example_class.new(relation_name, nil, nil, NoteWithCallback.all, "specific_type", :notable).foreign_type.should eq("specific_type")
      end
    end
  end

  describe "#condition_clause" do
    context "without custom query" do
      it do
        condition = example_relation.condition_clause
        condition.should eq((note.c(:notable_id, relation_name) == profile.c(:id)) & (note.c(:notable_type, relation_name) == "ProfileWithOneNote"))
      end

      describe "for specific id" do
        it do
          condition = example_relation.condition_clause(1)
          condition.should eq((note.c(:notable_id, relation_name) == 1) & (note.c(:notable_type, relation_name) == "ProfileWithOneNote"))
        end
      end

      describe "for specific ids" do
        it do
          condition = example_relation.condition_clause([1, 2, 3])
          condition.should eq((note.c(:notable_id, relation_name).in([1, 2, 3])) & (note.c(:notable_type, relation_name) == "ProfileWithOneNote"))
        end
      end
    end

    context "with custom query" do
      pending "add" do
      end
    end
  end

  describe "#insert" do
    context "with hash" do
      it do
        p = profile.find!(Factory.create_facebook_profile.id)
        n = example_relation.insert(p, {"text" => "text"} of String => Jennifer::DBAny)
        n.notable_id.should eq(p.id)
        n.notable_type.should eq(profile.to_s)
      end
    end

    context "with object" do
      it do
        p = profile.find!(Factory.create_facebook_profile.id)
        n = note.new({text: "some text"})
        n = example_relation.insert(p, n)
        n.notable_id.should eq(p.id)
        n.notable_type.should eq(profile.to_s)
      end

      it "raises exception if related object is already assigned" do
        p1 = profile.find!(Factory.create_facebook_profile.id)
        p2 = profile.find!(Factory.create_facebook_profile.id)
        n = note.new({text: "some text"})
        n = p2.add_note(n)
        expect_raises(Jennifer::BaseException) do
          example_relation.insert(p1, n)
        end
      end
    end
  end

  describe "#remove" do
    context "with given object" do
      it do
        p = profile.find!(Factory.create_facebook_profile.id)
        n = p.add_note(note.new({text: "some text"}))

        example_relation.remove(p, n)
        n.reload
        n.notable_type.should be_nil
        n.notable_id.should be_nil
      end
    end

    context "without related object" do
      it do
        p = profile.find!(Factory.create_facebook_profile.id)
        n = p.add_note(note.new({text: "some text"}))

        example_relation.remove(p)
        n.reload
        n.notable_type.should be_nil
        n.notable_id.should be_nil
      end
    end
  end
end
