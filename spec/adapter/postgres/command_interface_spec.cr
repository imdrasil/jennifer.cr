require "../../spec_helper"

postgres_only do
  describe Jennifer::Postgres::CommandInterface do
    described_class = Jennifer::Postgres::CommandInterface

    describe "#database_exists?" do
      it { described_class.new(Jennifer::Config.config).database_exists?.should be_true }

      it do
        config = Jennifer::Config.config
        config.db = "unexisting_test_database"
        described_class.new(config).database_exists?.should be_false
      end
    end
  end
end
