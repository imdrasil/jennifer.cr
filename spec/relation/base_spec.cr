require "../spec_helper"

describe Jennifer::Relation::Base do
  example_class = Jennifer::Relation::Base(NoteWithCallback, FacebookProfileWithDestroyNotable)
  relation_name = "notable"
  note = NoteWithCallback
  profile = FacebookProfileWithDestroyNotable
  query = NoteWithCallback.all
  example_relation = example_class.new(relation_name, :notable_id, nil, query)

  describe "#foreign_field" do
    context "without specified foreign field" do
      it do
        example_relation.foreign_field.should eq("notable_id")
      end
    end

    context "with specified foreign field" do
      it do
        example_class.new(relation_name, "specific_type", nil, query).foreign_field.should eq("specific_type")
      end
    end
  end

  describe "#primary_field" do
    context "without specified primary field" do
      it do
        example_relation.primary_field.should eq("id")
      end
    end

    context "with specified primary field" do
      it do
        example_class.new(relation_name, nil, "specific_type", query).primary_field.should eq("specific_type")
      end
    end
  end

  describe "#condition_clause" do
    context "without custom query" do
      it do
        condition = example_relation.condition_clause
        condition.should eq(note.c(:notable_id, relation_name) == profile.c(:id))
      end

      describe "for specific id" do
        it do
          condition = example_relation.condition_clause(1)
          condition.should eq(note.c(:notable_id, relation_name) == 1)
        end
      end

      describe "for specific ids" do
        it do
          condition = example_relation.condition_clause([1, 2, 3])
          condition.should eq(note.c(:notable_id, relation_name).in([1, 2, 3]))
        end
      end
    end

    context "with custom query" do
      pending "add" do
      end
    end
  end

  describe "#join_condition" do
    it do
      expected_query =
        profile.all.join(note, type: :left, relation: "notable") do
          example_relation.condition_clause.not_nil!
        end
      example_relation.join_condition(profile.all, :left).as_sql.should eq(expected_query.as_sql)
    end
  end

  describe "#query" do
    it do
      example_relation.query(1).tree.should eq(example_relation.condition_clause(1))
    end
  end

  describe "#insert" do
    context "with hash" do
      it do
        p = profile.find!(Factory.create_facebook_profile.id)
        n = example_relation.insert(p, {"text" => "text"} of String => Jennifer::DBAny)
        n.notable_id.should eq(p.id)
      end

      it do
        p = profile.find!(Factory.create_facebook_profile.id)
        n = example_relation.insert(p, {:text => "text"} of Symbol => Jennifer::DBAny)
        n.notable_id.should eq(p.id)
      end
    end

    context "with object" do
      it do
        p = profile.find!(Factory.create_facebook_profile.id)
        n = note.new({text: "some text"})
        n = example_relation.insert(p, n)
        n.notable_id.should eq(p.id)
      end
    end
  end

  describe "#remove" do
    context "with given object" do
      it do
        p = profile.find!(Factory.create_facebook_profile.id)
        n = note.create!(text: "some text", notable_id: p.id)

        example_relation.remove(p, n)
        n.reload
        n.notable_id.should be_nil
      end
    end
  end
end
