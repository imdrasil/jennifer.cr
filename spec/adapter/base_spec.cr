require "../spec_helper"

describe Jennifer::Adapter::Base do
  adapter = Jennifer::Adapter.adapter

  describe Jennifer::BadQuery do
    describe "query" do
      it "raises BadRequest if there was problem during method execution" do
        expect_raises(Jennifer::BadQuery, /Original query was/) do
          adapter.query("SELECT COUNT(id) as count FROM contacts where asd > $1", [1]) do |rs|
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
        c = Factory.create_contact
        c.name = "new name"
        r = adapter.update(c)
        r.rows_affected.should eq(1)
      end

      it "just returns exec result if nothing was changed" do
        c = Factory.create_contact
        r = adapter.update(c)
        r.rows_affected.should eq(0)
      end
    end
  end

  describe "#exec" do
    it "execs query" do
      adapter.exec("insert into countries(name) values('new')")
    end

    it "raises exception if query is broken" do
      expect_raises(Jennifer::BadQuery, /Original query was/) do
        adapter.exec("insert into countries(name) set values(?)", "new")
      end
    end
  end

  describe "#query" do
    it "perform query" do
      adapter.query("select * from countries") { |rs| read_to_end(rs) }
    end

    it "raises exception if query is broken" do
      expect_raises(Jennifer::BadQuery, /Original query was/) do
        adapter.query("select * from table countries") { |rs| read_to_end(rs) }
      end
    end
  end

  describe "#transaction" do
    it "rollbacks if exception was raised" do
      expect_raises(DivisionByZero) do
        adapter.transaction do
          Factory.create_contact
          1 / 0
        end
      end
      Contact.all.count.should eq(0)
    end

    it "commit transaction otherwice" do
      adapter.transaction do
        Factory.create_contact
      end
      Contact.all.count.should eq(1)
    end

    it "work with concurrent access" do
      begin
        ch = Channel(Nil).new
        adapter.transaction do |t|
          Factory.create_contact
          raise DB::Rollback.new
        end
        spawn do
          adapter.transaction do |t|
            Factory.create_contact
          end
          ch.send(nil)
        end
        ch.receive

        adapter.with_manual_connection do |con|
          con.scalar("select count(*) from contacts").should eq(1)
        end
      ensure
        adapter.with_manual_connection do |con|
          con.exec "DELETE FROM contacts"
        end
      end
    end
  end

  describe "#delete" do
    it "removes record from db" do
      Factory.create_contact
      adapter.delete(Factory.build_query(table: "contacts"))
      Contact.all.count.should eq(0)
    end
  end

  describe "#exists?" do
    it "returns true if record exists" do
      Factory.create_contact
      adapter.exists?(Factory.build_query(table: "contacts")).should be_true
    end

    it "returns false if record doesn't exist" do
      adapter.exists?(Factory.build_query(table: "contacts")).should be_false
    end
  end

  describe "#count" do
    it "returns count of objects" do
      Factory.create_contact
      adapter.count(Factory.build_query(table: "contacts")).should eq(1)
    end
  end

  describe "#table_exists?" do
    it "returns true if table exists" do
      adapter.table_exists?("contacts").should be_true
    end

    it "returns false if table not exists" do
      adapter.table_exists?("unknown_table").should be_false
    end
  end

  describe "#column_exists?" do
    it "returns true if table has given column" do
      adapter.column_exists?("contacts", "id").should be_true
    end

    it "returns false if table has no such olumn" do
      adapter.column_exists?("contacts", "some_field").should be_false
    end

    it "returns false if such table is not exists" do
      adapter.column_exists?("unknown", "id").should be_false
    end
  end

  describe "::join_table_name" do
    it "returns join table name in alphabetic order" do
      adapter.class.join_table_name("b", "a").should eq("a_b")
    end
  end

  describe "::parse_query" do
    pending "add" do
    end
  end
end
