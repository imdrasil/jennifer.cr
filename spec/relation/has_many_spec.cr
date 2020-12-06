require "../spec_helper"

describe Jennifer::Relation::HasMany do
  example_relation = Contact.addresses_relation

  pending "complete"

  describe "#condition_clause" do
    describe "for specific id" do
      it do
        condition = example_relation.condition_clause(1)
        condition.should eq(Address.c(:contact_id, "addresses") == 1)
      end
    end

    describe "for array ids" do
      it do
        condition = example_relation.condition_clause([1, 2, 3])
        condition.should eq(Address.c(:contact_id, "addresses").in([1, 2, 3]))
      end
    end
  end
end
