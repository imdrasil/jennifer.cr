require "../spec_helper"

describe Jennifer::Relation::ManyToMany do
  example_relation = Contact.countries_relation

  pending "complete"

  describe "#condition_clause" do
    describe "for specific id" do
      it do
        condition = example_relation.condition_clause(1)
        condition.should eq(Country.c(:contact_id, "countries") == 1)
      end
    end

    describe "for array ids" do
      it do
        condition = example_relation.condition_clause([1, 2, 3])
        condition.should eq(Country.c(:contact_id, "countries").in([1, 2, 3]))
      end
    end
  end
end
