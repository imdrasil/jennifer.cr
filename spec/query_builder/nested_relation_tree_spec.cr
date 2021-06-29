describe Jennifer::QueryBuilder::NestedRelationTree do
  builder = ->{ Jennifer::QueryBuilder::NestedRelationTree.new(Contact) }

  describe "#add_relation" do
    context "with defined query, relation, klass and index" do
      it do
        query = Contact.all
        tree = builder.call
        tree.add_relation(query, "contact", Passport, 1)
        tree.bucket[0].should eq({1, Passport.relation("contact")})
        query._joins!.size.should eq(1)
      end
    end
  end

  describe "#select_fields" do
    context "with table alias" do
      pending "add"
    end

    it do
      tree = builder.call
      query = Contact.all

      tree.add_relation(query, "passport")
      tree.select_fields(query).should eq([Contact.star, Passport.star])
    end
  end

  describe "#read" do
    pending "currently tested by ModelQuery#eager_load"
  end
end
