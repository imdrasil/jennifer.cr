require "./spec_helper"

describe Jennifer::Config do
  config = Jennifer::Config.config

  describe "::read" do
    it "reads data from yaml file" do
      config.read("./spec/fixtures/database.yml")
      config.db.should eq("jennifer_develop")
    end

    it "" do
      config.read("./spec/fixtures/database_with_nesting.yml", &.["database"]["development"])
      config.db.should eq("jennifer_develop")
    end
  end

  describe "::from_uri" do
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
        config.configure { |c| c.db = "" }
      end

      expect_raises(Jennifer::InvalidConfig, /No adapter configured/) do
        config.configure do |c|
          c.db = "somedb"
          c.adapter = ""
        end
      end
    end

    it "should ignore port if not supplied" do
      db_uri = "mysql://root@somehost/some_database"
      config.from_uri(db_uri)
      config.port.should eq(-1)
    end

    it "should parse connection params from the uri" do
      db_uri = "mysql://root@somehost/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555&retry_delay=666"
      config.from_uri(db_uri)
      config.max_pool_size.should eq(111)
      config.initial_pool_size.should eq(222)
      config.max_idle_pool_size.should eq(333)
      config.retry_attempts.should eq(444)
      config.checkout_timeout.should eq(555)
      config.retry_delay.should eq(666)
    end
  end
end
