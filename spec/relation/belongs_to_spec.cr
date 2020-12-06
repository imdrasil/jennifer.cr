require "../spec_helper"

describe Jennifer::Relation::BelongsTo do
  example_relation = Address.contact_relation

  describe "#condition_clause" do
    describe "for specific id" do
      it do
        condition = example_relation.condition_clause(1)
        condition.should eq(Contact.c(:id, "contact") == 1)
      end
    end

    describe "for array ids" do
      it do
        condition = example_relation.condition_clause([1, 2, 3])
        condition.should eq(Contact.c(:id, "contact").in([1, 2, 3]))
      end
    end
  end
end
