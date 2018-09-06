require "../spec_helper"

describe Jennifer::Adapter::Base do
  adapter = Jennifer::Adapter.adapter
  described_class = Jennifer::Adapter::Base

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
        Contact.all.eager_load(:gibberish).to_a
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
        adapter.exec("insert into countries(name) set values(?)", ["new"])
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
      void_transaction do
        expect_raises(DivisionByZeroError) do
          adapter.transaction do |tx|
            Factory.create_contact
            1 / 0
          end
        end
        Contact.all.count.should eq(0)
      end
    end

    it "commit transaction otherwise" do
      void_transaction do
        adapter.transaction do
          Factory.create_contact
        end
        Contact.all.count.should eq(1)
      end
    end

    # TODO: add several fibers and yields in them
    it "work with concurrent access" do
      void_transaction do
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

  describe "#truncate" do
    it "clean up db" do
      Factory.create_address
      adapter.truncate(Address.table_name)
      Address.all.count.should eq(0)
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

    it "returns false if table has no such column" do
      adapter.column_exists?("contacts", "some_field").should be_false
    end

    it "returns false if such table is not exists" do
      adapter.column_exists?("unknown", "id").should be_false
    end
  end

  describe "#bulk_insert" do
    it "do nothing if empty array was given" do
      expect_query_silence do
        adapter.bulk_insert([] of Contact)
      end
    end

    it "starts transaction" do
      void_transaction do
        c = Factory.build_contact
        adapter.bulk_insert([c])
        query_log.any? { |entry| entry =~ /TRANSACTION/ }.should be_true
      end
    end

    postgres_only do
      it "uses table lock" do
        void_transaction do
          c = Factory.build_contact
          adapter.bulk_insert([c])
          query_log.any? { |entry| entry =~ /LOCK TABLE/ }.should be_true
        end
      end
    end

    it "avoid model validation" do
      c = Factory.build_contact(age: 12)
      c.should_not be_valid
      adapter.bulk_insert([c])
      c = Contact.all.first!
      c.should_not be_valid
    end

    it "properly sets object attributes" do
      c = Factory.build_contact(name: "Syd", age: 150)
      adapter.bulk_insert([c])
      Contact.all.count.should eq(1)
      c = Contact.all.first!
      c.age.should eq(150)
      c.name.should eq("Syd")
    end
  end

  describe "::join_table_name" do
    it "returns join table name in alphabetic order" do
      adapter.class.join_table_name("b", "a").should eq("a_b")
    end
  end

  describe "::connection_string" do
    config = Jennifer::Config

    context "for db connection" do
      it "generates proper connection string" do
        config.password = "password"
        config.user = "user"
        config.host = "host"
        config.db = "db"

        db_connection_string = "#{config.adapter}://user:password@host/db?" \
                               "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0"
        adapter.class.connection_string(:db).should eq(db_connection_string)
      end

      context "with specified port" do
        it do
          config.password = "password"
          config.user = "user"
          config.host = "host"
          config.db = "db"
          config.port = 3000
          db_connection_string = "#{config.adapter}://user:password@host:3000/db?" \
                                 "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0"
          adapter.class.connection_string(:db).should eq(db_connection_string)
        end
      end
    end

    context "for general connection" do
      it "generates proper connection string" do
        config.password = "password"
        config.user = "user"
        config.host = "host"
        config.db = "db"

        connection_string = "#{config.adapter}://user:password@host?" \
                            "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0"
        adapter.class.connection_string.should eq(connection_string)
      end
    end

    context "with defined port" do
      it "generates proper connection string" do
        config.port = 3333
        config.password = ""
        connection_string = "#{config.adapter}://#{config.user}@#{config.host}:3333?" \
                            "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0"
        adapter.class.connection_string.should eq(connection_string)
      end
    end

    context "without password" do
      it do
        config.password = ""
        connection_string = /^#{config.adapter}\:\/\/#{config.user}@#{config.host}/
        adapter.class.connection_string.should match(connection_string)
      end
    end
  end

  describe "::extract_arguments" do
    res = described_class.extract_arguments({:asd => 1, "qwe" => "2"})

    it "converts all field names to string" do
      res[:fields].should eq(%w(asd qwe))
    end

    it "extracts all values to :args" do
      res[:args].should eq(db_array(1, "2"))
    end
  end

  describe "#query_array" do
    it "returns array of given type" do
      Factory.create_contact
      res = adapter.query_array("SELECT name FROM contacts", String)
      typeof(res).should eq(Array(Array(String)))
    end

    it "retrieves given amount of fields" do
      Factory.create_contact
      res = adapter.query_array("SELECT name, description FROM contacts", String?, 2)
      res[0].should eq(["Deepthi", nil])
    end
  end

  describe "#table_column_count" do
    context "given table name" do
      it "returns amount of table fields" do
        adapter.table_column_count("addresses").should eq(5)
      end
    end

    it "returns -1 if name is not a table or MV" do
      adapter.table_column_count("asdasd").should eq(-1)
    end
  end

  describe "#view_exists?" do
    it "returns true if given view exists" do
      adapter.view_exists?("male_contacts").should be_true
    end

    it "returns false if given view doesn't exist" do
      adapter.view_exists?("contacts").should be_false
    end
  end
end
