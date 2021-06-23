require "../spec_helper"

describe Jennifer::QueryBuilder::RelationTree do
  builder = ->{ Jennifer::QueryBuilder::MultiQueryRelationTree.new(Contact) }

  describe "#add_relation" do
    it do
      tree = builder.call
      tree.add_relation(:passport)
      tree.bucket[0].should eq({0, Contact.relation("passport")})
    end
  end

  describe "#add_deep_relation" do
    query = Contact.all

    context "with nested relation defined using symbol" do
      it do
        tree = builder.call
        tree.add_relation(:passport)
        tree.add_relation(:countries)

        tree.add_deep_relation(query, "countries", :cities)
        tree.bucket[2].should eq({2, Country.relation("cities")})
      end
    end

    context "with nested relation defined using hash" do
      it do
        tree = Jennifer::QueryBuilder::MultiQueryRelationTree.new(City)
        tree.add_relation(:country)

        tree.add_deep_relation(query, "country", {:contacts => :passport})
        tree.bucket[1].should eq({1, Country.relation("contacts")})
        tree.bucket[2].should eq({2, Contact.relation("passport")})
      end
    end

    context "with nested relation defined using named tuple" do
      it do
        tree = Jennifer::QueryBuilder::MultiQueryRelationTree.new(City)
        tree.add_relation(:country)

        tree.add_deep_relation(query, "country", {contacts: :passport})
        tree.bucket[1].should eq({1, Country.relation("contacts")})
        tree.bucket[2].should eq({2, Contact.relation("passport")})
      end
    end

    context "with nested relation defined using array" do
      it do
        tree = Jennifer::QueryBuilder::MultiQueryRelationTree.new(City)
        tree.add_relation(:country)

        tree.add_deep_relation(query, "country", [:contacts])
        tree.bucket[1].should eq({1, Country.relation("contacts")})
      end
    end
  end

  describe "#clone" do
    it do
      tree = builder.call
      clone = tree.clone

      clone.add_relation(:passport)
      tree.bucket.empty?.should be_true
    end
  end
end
