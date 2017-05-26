require "../minitest_helper"

# TODO: add checking for log entries when we shouldn't hit db
describe Jennifer do
  describe Jennifer::QueryBuilder::ModelQuery do
    describe "#includes" do
      it "loads relation as well" do
        c1 = contact_create(name: "asd")
        address_create(contact_id: c1.id, street: "asd st.")
        res = Contact.all.includes(:addresses).first!
        expect(res.addresses[0].street).must_equal("asd st.")
      end

      # pending "with aliases" do
      # end
    end

    describe "#relation" do
      it "makes join using relation scope" do
        expect(Contact.all.relation(:addresses).join_clause).must_match(/JOIN addresses ON addresses.contact_id = contacts.id/)
      end
    end

    describe "#destroy" do
      # it "add" do
      # end
    end

    describe "#first" do
      it "returns first record" do
        c1 = contact_create(age: 15)
        c2 = contact_create(age: 15)

        r = Contact.all.where { _age == 15 }.first!
        expect(r.id).must_equal(c1.id)
      end

      it "returns nil if there is no such records" do
        expect(Contact.all.first).must_be_nil
      end
    end

    describe "#last" do
      it "inverse all orders" do
        c1 = contact_create(age: 15)
        c2 = contact_create(age: 16)

        r = Contact.all.order(age: :desc).last!
        expect(r.id).must_equal(c1.id)
      end

      it "add order by primary key if no order was specified" do
        c1 = contact_create(age: 15)
        c2 = contact_create(age: 16)

        r = Contact.all.last!
        expect(r.id).must_equal(c2.id)
      end
    end
  end
end
