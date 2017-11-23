require "./spec_helper"

describe Jennifer::Config do
  describe "::read" do
    it "reads data from yaml file" do
      Jennifer::Config.read("./spec/fixtures/database.yml")
      Jennifer::Config.configure{ |config| config.db.should eq("jennifer_develop") }
    end
  end

  describe "::configure" do
    it "should always use default config if no key supplied" do
      ignoring_config_error do
        Jennifer::Config.configure do |without_key|
          Jennifer::Config.configure(:default) do |with_key|
            without_key.should eq(with_key)
          end
        end
      end
    end

    it "different keys supply different configs" do
      ignoring_config_error do
        Jennifer::Config.configure(:some_config) do |some_config|
          Jennifer::Config.configure(:another_config) do |another_config|
            some_config.should_not eq(another_config)
          end
        end
      end
    end

    it "same key supplies same config" do
      ignoring_config_error do
        Jennifer::Config.configure(:some_config) do |first|
          Jennifer::Config.configure(:some_config) do |second|
            raise "not the same config" unless first === second
          end
        end
      end
    end

    it "config accessible by string or symbol" do
      ignoring_config_error do
        Jennifer::Config.configure(:some_config) do |first|
          raise "not the same config" unless first === Jennifer::Config.get_instance("some_config")
        end
      end
    end

    it "config key is accessible from instance" do
      Jennifer::Config.get_instance.key.should eq("default")
      Jennifer::Config.get_instance(:some_config).key.should eq("some_config")
    end
  end

  describe "::from_uri" do
    it "should parse uri string" do
      db_uri = "mysql://root:password@somehost:3306/some_database"
      Jennifer::Config.from_uri(db_uri)
      Jennifer::Config.configure do |config|
        config.adapter.should eq("mysql")
        config.user.should eq("root")
        config.password.should eq("password")
        config.host.should eq("somehost")
        config.port.should eq(3306)
        config.db.should eq("some_database")
      end
    end

    it "expects adapter and database at very least" do
      expect_raises(Jennifer::InvalidConfig, /No database configured/) do
        Jennifer::Config.configure {|c| c.db = ""}
      end

      expect_raises(Jennifer::InvalidConfig, /No adapter configured/) do
        Jennifer::Config.configure do |c|
          c.db = "somedb"
          c.adapter = ""
        end
      end
    end

    it "should ignore port if not supplied" do
      Jennifer::Config.from_uri("mysql://root@somehost/some_database")
      Jennifer::Config.port.should eq(-1)
    end

    it "should parse connection params from the uri" do
      db_uri = "mysql://root@somehost/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555&retry_delay=666"
      Jennifer::Config.from_uri(db_uri)
      Jennifer::Config.max_pool_size.should eq(111)
      Jennifer::Config.initial_pool_size.should eq(222)
      Jennifer::Config.max_idle_pool_size.should eq(333)
      Jennifer::Config.retry_attempts.should eq(444)
      Jennifer::Config.checkout_timeout.should eq(555)
      Jennifer::Config.retry_delay.should eq(666)
    end
  end

  describe "::connection_string" do
    it "should build a connection string from config" do
      loaded_uri = "mysql://root:somepass@somehost/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555.0&retry_delay=666.0"
      Jennifer::Config.from_uri(loaded_uri)
      Jennifer::Config.connection_string(:db).should eq(loaded_uri)
    end

    it "should ignore password if unset" do
      clear_password
      loaded_uri = "mysql://root@somehost/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555.0&retry_delay=666.0"
      Jennifer::Config.from_uri(loaded_uri)
      Jennifer::Config.connection_string(:db).should eq(loaded_uri)
    end

    it "should build host part with host:port " do
      clear_password
      loaded_uri = "mysql://root@somehost:5432/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555.0&retry_delay=666.0"
      Jennifer::Config.from_uri(loaded_uri)
      Jennifer::Config.connection_string(:db).should eq(loaded_uri)
    end
  end
end

def clear_password
  Jennifer::Config.configure do |config|
    config.password = ""
  end
end

def ignoring_config_error(&block)
  yield
rescue e : Jennifer::InvalidConfig
end
