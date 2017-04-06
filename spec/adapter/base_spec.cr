require "../spec_helper"

describe Jennifer::Adapter::Base do
  describe Jennifer::BadQuery do
    describe "query" do
      it "raises BadRequest if there was problem during method execution" do
        expect_raises(Jennifer::BadQuery, /Original query was/) do
          Jennifer::Adapter.query(
            "SELECT COUNT(id) as count FROM contacts where asd > $1", [1]) do |rs|
            rs.each do
              rs.columns.size.times do
                rs.read
              end
            end
          end
        end
      end
    end
  end

  describe Jennifer::UnknownRelation do
    it "raises UnknownRelation when joining unknown relation" do
      expect_raises(Jennifer::UnknownRelation, "Unknown relation for Contact: gibberish") do
        Contact.all.includes(:gibberish).to_a
      end
    end
  end

  describe "#update" do
    context "given object" do
      it "updates fields if they were changed" do
        c = contact_create
        c.name = "new name"
        r = Jennifer::Adapter.adapter.update(c)
        r.rows_affected.should eq(1)
      end

      it "just returns exec result if nothing was changed" do
        c = contact_create
        r = Jennifer::Adapter.adapter.update(c)
        r.rows_affected.should eq(0)
      end
    end
  end
end
