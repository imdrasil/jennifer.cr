require "../spec_helper"

describe Jennifer::QueryBuilder::Ordering do
  describe "#order" do
    context "with named tuple" do
      it "converts all keys to criterion" do
        orders = Contact.all.order(age: :desc, id: "asc")._order!
        orders.should eq([Contact._age.desc, Contact._id.asc])
      end
    end

    context "with hash with string keys" do
      it "treats all keys as raw SQL" do
        orders = Contact.all.order({"age" => :desc})._order!
        orders.should eq([Contact.context.sql("age").desc])
      end
    end

    context "with hash with symbol keys" do
      it "treats all keys as criterion" do
        orders = Contact.all.order({:age => :desc})._order!
        orders.should eq([Contact._age.desc])
      end
    end

    context "with hash with mixed keys" do
      it do
        orders = Contact.all.order({:age => :desc, "id" => :asc})._order!
        orders.should eq([Contact._age.desc, Contact.context.sql("id").asc])
      end
    end

    context "with array of orders" do
      it "adds them to pool" do
        orders = Contact.all.order([Contact._id.desc])._order!
        orders.should eq([Contact._id.desc])
      end

      it "marks raw SQL not to use brackets" do
        orders = Contact.all.order([Contact.context.sql("raw sql").desc, Contact._id.asc])._order!
        orders.should eq([Contact.context.sql("raw sql").desc, Contact._id.asc])
        orders[0].criteria.identifier.should eq("raw sql")
      end
    end

    context "with block" do
      it "marks raw SQL not to use brackets" do
        orders = Contact.all.order { [sql("raw sql").desc, _id.asc] }._order!
        orders.should eq([Contact.context.sql("raw sql").desc, Contact._id.asc])
        orders[0].criteria.identifier.should eq("raw sql")
      end
    end
  end

  describe "#reorder" do
    context "with named tuple" do
      it "converts all keys to criterion" do
        base_query = Contact.all.order(id: :desc)
        orders = base_query.reorder(age: :desc, id: "asc")._order!
        orders.should eq([Contact._age.desc, Contact._id.asc])
      end
    end

    context "with hash with string keys" do
      it "treats all keys as raw SQL without brackets" do
        orders = Contact.all.order(id: :desc).reorder({"age" => :desc})._order!
        orders.should eq([Contact.context.sql("age").desc])
      end
    end

    context "with hash with symbol keys" do
      it "treats all keys as criterion" do
        orders = Contact.all.order(id: :desc).reorder({:age => :desc})._order!
        orders.should eq([Contact._age.desc])
      end
    end

    context "with hash with criterion as keys" do
      it "adds them to pool" do
        base_query = Contact.all.order(id: :desc)
        orders = base_query.reorder([Contact._id.desc])._order!
        orders.should eq([Contact._id.desc])
      end

      it "marks raw SQL not to use brackets" do
        base_query = Contact.all.order(id: :desc)
        orders = base_query.reorder([Contact.context.sql("raw sql").desc, Contact._id.asc])._order!
        orders.should eq([Contact.context.sql("raw sql").desc, Contact._id.asc])
        orders[0].criteria.identifier.should eq("raw sql")
      end
    end

    context "with block" do
      it "marks raw SQL not to use brackets" do
        base_query = Contact.all.order(id: :desc)
        orders = base_query.reorder { [sql("raw sql").desc, _id.asc] }._order!
        orders.should eq([Contact.context.sql("raw sql").desc, Contact._id.asc])
        orders[0].criteria.identifier.should eq("raw sql")
      end
    end
  end
end
