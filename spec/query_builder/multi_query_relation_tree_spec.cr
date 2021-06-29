describe Jennifer::QueryBuilder::MultiQueryRelationTree do
  query = Contact.all
  builder = ->{ Jennifer::QueryBuilder::MultiQueryRelationTree.new(Contact) }

  describe "#add_relation" do
    context "with defined query, relation, klass and index" do
      it do
        tree = builder.call
        tree.add_relation(query, :contact, Passport, 1)
        tree.bucket[0].should eq({1, Passport.relation("contact")})
        query._joins?.should be_nil
      end
    end
  end

  describe "#preload" do
    context "without nested relations" do
      it do
        tree = builder.call
        c = Factory.create_contact
        Factory.create_address(contact_id: c.id)
        collection = query.to_a
        tree.add_relation(query, :passport)
        tree.add_relation(query, :addresses)

        tree.preload(collection)

        expect_query_silence do
          collection[0].passport
          collection[0].addresses.size.should eq(1)
        end
      end
    end

    context "with has_many nested relation" do
      pending "currently tested by ModelQuery#includes"
    end

    context "with has_and_belongs_to_many nested relation" do
      pending "currently tested by ModelQuery#includes"
    end

    context "with belongs_to nested relation" do
      pending "currently tested by ModelQuery#includes"
    end

    context "with has_one nested relation" do
      pending "currently tested by ModelQuery#includes"
    end
  end
end
