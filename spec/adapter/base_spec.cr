require "../spec_helper"

private def config
  Jennifer::Config.instance
end

private def adapter
  Jennifer::Adapter.default_adapter_class.not_nil!.new(Jennifer::Config.instance)
end

default_adapter = Jennifer::Adapter.default_adapter

describe Jennifer::Adapter::Base do
  describe Jennifer::BadQuery do
    describe "query" do
      it "raises BadRequest if there was problem during method execution" do
        expect_raises(Jennifer::BadQuery, /Original query was/) do
          default_adapter.query("SELECT COUNT(id) as count FROM contacts where asd > $1", [1]) { }
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
        r = default_adapter.update(c)
        r.rows_affected.should eq(1)
      end

      it "just returns exec result if nothing was changed" do
        c = Factory.create_contact
        r = default_adapter.update(c)
        r.rows_affected.should eq(0)
      end
    end
  end

  describe "#exec" do
    it "execs query" do
      default_adapter.exec("insert into countries(name) values('new')")
    end

    it "raises exception if query is broken" do
      expect_raises(Jennifer::BadQuery, /Original query was/) do
        default_adapter.exec("insert into countries(name) set values(?)", ["new"])
      end
    end
  end

  describe "#query" do
    it "perform query" do
      default_adapter.query("select * from countries") { |rs| read_to_end(rs) }
    end

    it "raises exception if query is broken" do
      expect_raises(Jennifer::BadQuery, /Original query was/) do
        default_adapter.query("select * from table countries") { |rs| read_to_end(rs) }
      end
    end
  end

  describe "#transaction" do
    it "rollbacks if exception was raised" do
      void_transaction do
        expect_raises(DivisionByZeroError) do
          default_adapter.transaction do
            Factory.create_contact
            1 // 0
          end
        end
        Contact.all.count.should eq(0)
      end
    end

    it "commit transaction otherwise" do
      void_transaction do
        default_adapter.transaction do
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
          default_adapter.transaction do
            Factory.create_contact

            spawn do
              default_adapter.transaction do
                Factory.create_contact
              end
              ch.send(nil)
            end

            raise DB::Rollback.new
          end

          ch.receive

          default_adapter.db.using_connection do |con|
            con.scalar("select count(*) from contacts").should eq(1)
          end
        end
      end
    end
  end

  describe "#delete" do
    it "removes record from db" do
      Factory.create_contact
      default_adapter.delete(Factory.build_query(table: "contacts"))
      Contact.all.count.should eq(0)
    end
  end

  describe "#truncate" do
    it "clean up db" do
      Factory.create_address
      default_adapter.truncate(Address.table_name)
      Address.all.count.should eq(0)
    end
  end

  describe "#exists?" do
    it "returns true if record exists" do
      Factory.create_contact
      default_adapter.exists?(Factory.build_query(table: "contacts")).should be_true
    end

    it "returns false if record doesn't exist" do
      default_adapter.exists?(Factory.build_query(table: "contacts")).should be_false
    end
  end

  describe "#count" do
    it "returns count of objects" do
      Factory.create_contact
      default_adapter.count(Factory.build_query(table: "contacts")).should eq(1)
    end
  end

  describe "#table_exists?" do
    it "returns true if table exists" do
      default_adapter.table_exists?("contacts").should be_true
    end

    it "returns false if table not exists" do
      default_adapter.table_exists?("unknown_table").should be_false
    end
  end

  describe "#column_exists?" do
    it "returns true if table has given column" do
      default_adapter.column_exists?("contacts", "id").should be_true
    end

    it "returns false if table has no such column" do
      default_adapter.column_exists?("contacts", "some_field").should be_false
    end

    it "returns false if such table is not exists" do
      default_adapter.column_exists?("unknown", "id").should be_false
    end
  end

  describe "#foreign_key_exists?" do
    context "with to_table" do
      it { default_adapter.foreign_key_exists?(:addresses, :contacts).should be_true }
    end

    context "with foreign key name" do
      it { default_adapter.foreign_key_exists?(:addresses, name: "fk_cr_67e9674de3").should be_true }
    end

    context "with column name" do
      it { default_adapter.foreign_key_exists?(:addresses, column: :contact_id).should be_true }
    end

    context "with invalid name" do
      it do
        default_adapter.foreign_key_exists?("fk_cr_contacts_addresses").should be_false
      end
    end
  end

  describe "#bulk_insert" do
    it "do nothing if empty array was given" do
      expect_query_silence do
        default_adapter.bulk_insert([] of Contact)
      end
    end

    # it "starts transaction" do
    #   void_transaction do
    #     c = Factory.build_contact
    #     default_adapter.bulk_insert([c])
    #     query_log.any? { |entry| entry[:query].to_s =~ /BEGIN/ }.should be_true
    #   end
    # end

    # postgres_only do
    #   it "uses table lock" do
    #     void_transaction do
    #       c = Factory.build_contact
    #       default_adapter.bulk_insert([c])
    #       query_log.any? { |entry| entry[:query].to_s =~ /LOCK TABLE/ }.should be_true
    #     end
    #   end
    # end

    it "avoid model validation" do
      c = Factory.build_contact(age: 12)
      c.should_not be_valid
      default_adapter.bulk_insert([c])
      c = Contact.all.first!
      c.should_not be_valid
    end

    it "properly sets object attributes" do
      c = Factory.build_contact(name: "Syd", age: 150)
      default_adapter.bulk_insert([c])
      Contact.all.count.should eq(1)
      c = Contact.all.first!
      c.age.should eq(150)
      c.name.should eq("Syd")
    end

    context "with array of hashes" do
      argument_regex = db_specific(mysql: ->{ /\(\?/ }, postgres: ->{ /\(\$\d/ })
      amount = 4681
      fields = %w(name ballance age description created_at updated_at user_id)
      values = ["Deepthi", nil, 28, nil, nil, nil, nil] of Jennifer::DBAny

      it "imports objects by prepared statement" do
        Contact.all.count.should eq(0)
        default_adapter.bulk_insert(Contact.table_name, fields, (amount - 1).times.map { values }.to_a)
        query_log[1][:query].to_s.should match(argument_regex)
        Contact.all.count.should eq(amount - 1)
      end

      context "when count of fields exceeds supported limit" do
        it "imports objects escaping their values in query" do
          Contact.all.count.should eq(0)
          default_adapter.bulk_insert(Contact.table_name, fields, amount.times.map { values }.to_a)
          query_log[1][:query].to_s.should_not match(argument_regex)
          Contact.all.count.should eq(amount)
        end
      end
    end
  end

  describe "#upsert" do
    it "do nothing if empty array was given" do
      expect_query_silence do
        default_adapter.upsert([] of Contact, [] of String)
      end
    end

    it "avoid model validation" do
      c = Factory.build_contact(age: 12)
      c.should_not be_valid
      default_adapter.upsert([c], [] of String)
      c = Contact.all.first!
      c.should_not be_valid
    end

    it "properly sets object attributes" do
      c = Factory.build_contact(name: "Syd", age: 150)
      default_adapter.upsert([c], [] of String)
      Contact.all.count.should eq(1)
      c = Contact.all.first!
      c.age.should eq(150)
      c.name.should eq("Syd")
    end

    it "ignore duplicate values" do
      contact = Factory.build_contact
      contact.description = "unique"
      contact.save.should be_true

      c = Factory.build_contact(age: 12, description: "unique")
      default_adapter.upsert([c], [] of String)
      Contact.all.count.should eq(1)
      Contact.all.first!.age.should_not eq(12)
    end

    postgres_only do
      it "still conflict if not in unique fields" do
        contact = Factory.build_contact
        contact.description = "not unique"
        contact.email = "unique@email"
        contact.save.should be_true

        c = Factory.build_contact(age: 12, description: "not unique either", email: "unique@email")
        expect_raises(Jennifer::BadQuery, /duplicate key value violates unique constraint "contacts_email_idx"/) do
          default_adapter.upsert([c], ["description"] of String)
        end
      end
    end

    context "with array of hashes" do
      argument_regex = db_specific(mysql: ->{ /\(\?/ }, postgres: ->{ /\(\$\d/ })
      amount = 4681
      fields = %w(name ballance age description created_at updated_at user_id)
      values = ["Deepthi", nil, 28, nil, nil, nil, nil] of Jennifer::DBAny

      it "imports objects by prepared statement" do
        Contact.all.count.should eq(0)
        default_adapter.upsert(Contact.table_name, fields, (amount - 1).times.map { values }.to_a, [] of String, {} of Nil => Nil)
        query_log[1][:query].to_s.should match(argument_regex)
        Contact.all.count.should eq(amount - 1)
      end
    end
  end

  describe ".join_table_name" do
    it "returns join table name in alphabetic order" do
      default_adapter.class.join_table_name("b", "a").should eq("a_b")
    end
  end

  describe "#connection_string" do
    context "for db connection" do
      it "generates proper connection string" do
        config.password = "password"
        config.user = "user"
        config.host = "host"
        config.db = "db"

        db_connection_string = "#{config.adapter}://user:password@host/db?" \
                               "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0"
        adapter.connection_string(:db).should eq(db_connection_string)
      end

      it "escapes user, password and query" do
        config.password = "/ @&?"
        config.user = "weird@name"
        config.host = "host"
        config.db = "database"

        db_connection_string = "#{config.adapter}://weird%40name:%2F+%40%26%3F@host/database?" \
                               "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0"
        adapter.connection_string(:db).should eq(db_connection_string)
      end

      context "with specified port" do
        it do
          config.password = "password"
          config.user = "user"
          config.host = "host"
          config.db = "db"
          config.port = 3000
          db_connection_string = "#{adapter.class.protocol}://user:password@host:3000/db?" \
                                 "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0"
          adapter.connection_string(:db).should eq(db_connection_string)
        end
      end
    end

    context "for general connection" do
      it "generates proper connection string" do
        config.password = "password"
        config.user = "user"
        config.host = "host"
        config.db = "db"
        config.port = -1

        connection_string = "#{adapter.class.protocol}://user:password@host?" \
                            "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0"
        adapter.connection_string(:root).should eq(connection_string)
      end
    end

    context "with defined port" do
      it "generates proper connection string" do
        config.port = 3333
        config.password = ""
        connection_string = "#{adapter.class.protocol}://#{config.user}@#{config.host}:3333?" \
                            "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0"
        adapter.connection_string(:root).should eq(connection_string)
      end
    end

    context "with defined auth_methods" do
      it "generates proper connection string" do
        config.port = -1
        config.password = ""
        config.auth_methods = "cleartext,md5,scram-sha-256"
        connection_string = "#{adapter.class.protocol}://#{config.user}@#{config.host}?" \
                            "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0&auth_methods=cleartext%2Cmd5%2Cscram-sha-256"
        adapter.connection_string(:root).should eq(connection_string)
      end
    end

    context "with defined sslmode" do
      it "generates proper connection string" do
        config.port = -1
        config.password = ""
        config.sslmode = "verify-full"
        connection_string = "#{adapter.class.protocol}://#{config.user}@#{config.host}?" \
                            "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0&sslmode=verify-full"
        adapter.connection_string(:root).should eq(connection_string)
      end
    end

    context "with defined sslmode and sslcert" do
      it "generates proper connection string" do
        config.port = -1
        config.password = ""
        config.sslmode = "verify-full"
        config.sslcert = "/path/to/ssl.crt"
        connection_string = "#{adapter.class.protocol}://#{config.user}@#{config.host}?" \
                            "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0&sslmode=verify-full&sslcert=%2Fpath%2Fto%2Fssl.crt"
        adapter.connection_string(:root).should eq(connection_string)
      end
    end

    context "with defined sslmode and sslkey" do
      it "generates proper connection string" do
        config.port = -1
        config.password = ""
        config.sslmode = "verify-full"
        config.sslkey = "/path/to/ssl.key"
        connection_string = "#{adapter.class.protocol}://#{config.user}@#{config.host}?" \
                            "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0&sslmode=verify-full&sslkey=%2Fpath%2Fto%2Fssl.key"
        adapter.connection_string(:root).should eq(connection_string)
      end
    end

    context "with defined sslmode and sslrootcert" do
      it "generates proper connection string" do
        config.port = -1
        config.password = ""
        config.sslmode = "verify-full"
        config.sslrootcert = "/path/to/sslroot.crt"
        connection_string = "#{adapter.class.protocol}://#{config.user}@#{config.host}?" \
                            "max_pool_size=1&initial_pool_size=1&max_idle_pool_size=1&retry_attempts=1&checkout_timeout=5.0&retry_delay=1.0&sslmode=verify-full&sslrootcert=%2Fpath%2Fto%2Fsslroot.crt"
        adapter.connection_string(:root).should eq(connection_string)
      end
    end

    context "without password" do
      it do
        config.password = ""
        connection_string = /^#{adapter.class.protocol}\:\/\/#{config.user}@#{config.host}/
        adapter.connection_string(:root).should match(connection_string)
      end
    end

    context "without username or password" do
      it do
        config.user = ""
        config.password = ""
        connection_string = /^#{adapter.class.protocol}\:\/\/#{config.host}/
        adapter.connection_string(:root).should match(connection_string)
      end
    end
  end

  describe "#query_array" do
    it "returns array of given type" do
      Factory.create_contact
      res = default_adapter.query_array("SELECT name FROM contacts", String)
      typeof(res).should eq(Array(Array(String)))
    end

    it "retrieves given amount of fields" do
      Factory.create_contact
      res = default_adapter.query_array("SELECT name, description FROM contacts", String?, 2)
      res[0].should eq(["Deepthi", nil])
    end
  end

  describe "#table_column_count" do
    context "given table name" do
      it "returns amount of table fields" do
        default_adapter.table_column_count("addresses").should eq(7)
      end
    end

    it "returns -1 if name is not a table or MV" do
      default_adapter.table_column_count("asdasd").should eq(-1)
    end
  end

  describe "#tables_column_count" do
    it "returns amount of tables fields" do
      default_adapter.tables_column_count(["passports", "addresses"]).to_a.map(&.count).should match_array([2, 7])
    end

    postgres_only do
      it "returns amount of views fields" do
        default_adapter.tables_column_count(["male_contacts", "female_contacts"]).to_a.map(&.count).should match_array([9, 10])
      end
    end

    mysql_only do
      it "returns amount of views fields" do
        default_adapter.tables_column_count(["male_contacts"]).to_a.map(&.count).should match_array([9])
      end
    end

    it "returns nothing for unknown tables" do
      default_adapter.tables_column_count(["missing_table"]).to_a.should be_empty
    end
  end

  describe "#view_exists?" do
    it "returns true if given view exists" do
      default_adapter.view_exists?("male_contacts").should be_true
    end

    it "returns false if given view doesn't exist" do
      default_adapter.view_exists?("contacts").should be_false
    end
  end
end
