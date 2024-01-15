require "./spec_helper"

private def config
  Jennifer::Config.config
end

describe Jennifer::Config do
  described_class = Jennifer::Config

  describe ".read" do
    it "reads data from yaml file" do
      config.read("./spec/fixtures/database.yml")
      config.db.should eq("jennifer_develop")
    end

    it do
      config.read("./spec/fixtures/database_with_nesting.yml", &.["database"]["development"])
      config.db.should eq("jennifer_develop")
    end
  end

  describe ".from_uri" do
    it "should parse uri string" do
      db_uri = "mysql://root:password@somehost:3306/some_database"
      config.from_uri(db_uri)
      config.adapter.should eq("mysql")
      config.user.should eq("root")
      config.password.should eq("password")
      config.host.should eq("somehost")
      config.port.should eq(3306)
      config.db.should eq("some_database")
    end

    it "expects adapter and database at very least" do
      expect_raises(Jennifer::InvalidConfig, /No database configured/) do
        described_class.configure(&.db=(""))
      end

      expect_raises(Jennifer::InvalidConfig, /No adapter configured/) do
        described_class.configure do |conf|
          conf.db = "somedb"
          conf.adapter = ""
        end
      end
    end

    it "should ignore port if not supplied" do
      db_uri = "mysql://root@somehost/some_database"
      config.from_uri(db_uri)
      config.port.should eq(-1)
    end

    it "should parse connection params from the uri" do
      db_uri = "mysql://root@somehost/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555&retry_delay=666&auth_methods=cleartext,md5,scram-sha-256&sslmode=verify-full&sslcert=/path/to/ssl.crt&sslkey=/path/to/ssl.key&sslrootcert=/path/to/sslroot.crt"
      config.from_uri(db_uri)
      config.max_pool_size.should eq(111)
      config.initial_pool_size.should eq(222)
      config.max_idle_pool_size.should eq(333)
      config.retry_attempts.should eq(444)
      config.checkout_timeout.should eq(555)
      config.retry_delay.should eq(666)
      config.auth_methods.should eq("cleartext,md5,scram-sha-256")
      config.sslmode.should eq("verify-full")
      config.sslcert.should eq("/path/to/ssl.crt")
      config.sslkey.should eq("/path/to/ssl.key")
      config.sslrootcert.should eq("/path/to/sslroot.crt")
    end
  end
end
