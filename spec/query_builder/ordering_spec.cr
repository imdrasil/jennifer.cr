require "../spec_helper"

describe Jennifer::QueryBuilder::Ordering do
  described_class = Jennifer::QueryBuilder::Query

  describe "#order" do
    context "with named tuple" do
      it "converts all keys to criterias" do
        orders = Contact.all.order(age: :desc, id: "asc")._order
        orders.size.should eq(2)
        orders = orders.keys
        orders[0].table.should eq("contacts")
        orders[0].field.should eq("age")
      end
    end

    context "with hash with string keys" do
      it "treats all keys as raw sql without brackets" do
        orders = Contact.all.order({"age" => :desc})._order
        orders.keys[0].is_a?(Jennifer::QueryBuilder::RawSql)
        orders.keys[0].identifier.should eq("age")
        orders.values[0].should eq("desc")
      end
    end

    context "with hash with symbol keys" do
      it "treats all keys as criterias" do
        orders = Contact.all.order({:age => :desc})._order.keys
        orders[0].identifier.should eq("contacts.age")
      end
    end

    context "wiht hash with criterias as keys" do
      it "adds them to pool" do
        orders = Contact.all.order({Contact._id => :desc})._order
        orders.keys[0].identifier.should eq("contacts.id")
      end

      it "marks raw sql not to use brackets" do
        orders = Contact.all.order({Contact.context.sql("raw sql") => :desc, Contact._id => "asc"})._order.keys
        orders[0].identifier.should eq("raw sql")
      end
    end

    context "with block" do
      it "marks raw sql not to use brackets" do
        orders = Contact.all.order { {sql("raw sql") => :desc, _id => "asc"} }._order.keys
        orders[0].identifier.should eq("raw sql")
      end
    end
  end

  describe "#reorder" do
    context "with named tuple" do
      it "converts all keys to criterias" do
        base_query = Contact.all.order(id: :desc)

        orders = base_query.reorder(age: :desc, id: "asc")._order
        orders.size.should eq(2)
        orders = orders.keys
        orders[0].table.should eq("contacts")
        orders[0].field.should eq("age")
      end
    end

    context "with hash with string keys" do
      it "treats all keys as raw sql without brackets" do
        base_query = Contact.all.order(id: :desc)
        orders = base_query.reorder({"age" => :desc})._order
        orders.keys[0].is_a?(Jennifer::QueryBuilder::RawSql)
        orders.keys[0].identifier.should eq("age")
        orders.values[0].should eq("desc")
      end
    end

    context "with hash with symbol keys" do
      it "treats all keys as criterias" do
        base_query = Contact.all.order(id: :desc)

        orders = base_query.reorder({:age => :desc})._order.keys
        orders[0].identifier.should eq("contacts.age")
      end
    end

    context "wiht hash with criterias as keys" do
      it "adds them to pool" do
        base_query = Contact.all.order(id: :desc)
        orders = base_query.reorder({Contact._id => :desc})._order
        orders.keys[0].identifier.should eq("contacts.id")
      end

      it "marks raw sql not to use brackets" do
        base_query = Contact.all.order(id: :desc)
        orders = base_query.reorder({Contact.context.sql("raw sql") => :desc, Contact._id => "asc"})._order.keys
        orders[0].identifier.should eq("raw sql")
      end
    end

    context "with block" do
      it "marks raw sql not to use brackets" do
        base_query = Contact.all.order(id: :desc)
        orders = base_query.reorder { {sql("raw sql") => :desc, _id => "asc"} }._order.keys
        orders[0].identifier.should eq("raw sql")
      end
    end
  end
end
