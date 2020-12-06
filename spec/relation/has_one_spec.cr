require "../spec_helper"

describe Jennifer::Relation::HasOne do
  example_relation = Contact.main_address_relation

  pending "add"

  describe "#condition_clause" do
    context "with custom query" do
      describe "for specific id" do
        it do
          condition = example_relation.condition_clause(1)
          condition.should eq(Address.c(:contact_id, "main_address").==(1) & Address.c(:main, "main_address"))
        end
      end

      describe "for array ids" do
        it do
          condition = example_relation.condition_clause([1, 2, 3])
          condition.should eq(Address.c(:contact_id, "main_address").in([1, 2, 3]) & Address.c(:main, "main_address"))
        end
      end
    end
  end
end
