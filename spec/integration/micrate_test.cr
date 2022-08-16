require "./spec_helper"

# drop existing db before running tests
DatabaseSeeder.drop

describe "Micrate usage" do
  describe "up" do
    it do
      clean do
        DatabaseSeeder.create
        with_connection do
          execute("crystal scripts/micrate.cr", ["up"]).should succeed
          jennifer_adapter.table_exists?(:test_contacts).should be_true
        end
      end
    end
  end

  describe "down" do
    it do
      clean do
        DatabaseSeeder.create
        with_connection do
          execute("crystal scripts/micrate.cr", ["up"]).should succeed # we need to populate migrations table
          execute("crystal scripts/micrate.cr", ["down"]).should succeed
          jennifer_adapter.table_exists?(:test_contacts).should be_false
        end
      end
    end
  end
end
