require "./shared_helpers"
require "./spec_helper"

POOL_SIZE = 3

exit 0 if Spec.adapter != "mysql"

Jennifer::Config.configure do |conf|
  conf.logger.level = Logger::INFO
  conf.host = "localhost"
  conf.adapter = Spec.adapter
  conf.migration_files_path = "./examples/migrations"
  conf.db = "jennifer_test"
  conf.max_pool_size = POOL_SIZE
  conf.initial_pool_size = POOL_SIZE
  conf.max_idle_pool_size = POOL_SIZE
  conf.checkout_timeout = 1.0

  case Spec.adapter
  when "mysql"
    conf.user = ENV["DB_USER"]? || "root"
    conf.password = ""
  when "postgres"
    conf.user = ENV["DB_USER"]? || "developer"
    conf.password = ENV["DB_PASSWORD"]? || "1qazxsw2"
  else
    raise "Unknown adapter #{Spec.adapter}"
  end
end

Spec.before_each do
  (Jennifer::Model::Base.models - [Jennifer::Migration::Version]).each { |model| model.all.delete }
end

describe "Concurrent execution" do
  adapter = Jennifer::Adapter.adapter
  tread_count = POOL_SIZE + 1

  describe "Jennifer::Adapter::Base" do
    sleep_command =
      case Spec.adapter
      when "mysql"
        "SELECT SLEEP(2)"
      when "postgres"
        "SELECT pg_sleep(2)"
      else
        raise "Unknown adapter #{Spec.adapter}"
      end

    describe "#exec" do
      it "raises native db exception" do
        ch = Channel(String).new
        tread_count.times do
          spawn do
            begin
              adapter.exec(sleep_command)
              ch.send("")
            rescue e : Exception
              ch.send(e.class.to_s)
            end
          end
        end

        responses = (0...tread_count).map { ch.receive }
        responses.includes?("DB::PoolTimeout").should be_true
      end
    end

    describe "#query" do
      it "raises native db exception" do
        ch = Channel(String).new
        tread_count.times do
          spawn do
            begin
              adapter.query(sleep_command) do |rs|
                rs.each do
                  rs.columns.size.times do
                    rs.read
                  end
                end
              end

              ch.send("")
            rescue e : Exception
              ch.send(e.class.to_s)
            end
          end
        end

        responses = (0...tread_count).map { ch.receive }
        responses.includes?("DB::PoolTimeout").should be_true
      end
    end

    describe "#scalar" do
      it "raises native db exception" do
        ch = Channel(String).new
        tread_count.times do
          spawn do
            begin
              adapter.scalar(sleep_command)
              ch.send("")
            rescue e : Exception
              ch.send(e.class.to_s)
            end
          end
        end

        responses = (0...tread_count).map { ch.receive }
        responses.includes?("DB::PoolTimeout").should be_true
      end
    end
  end
end
