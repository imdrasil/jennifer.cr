require "./spec_helper"

POOL_SIZE     = 2
TIME_TO_SLEEP = 3

if Spec.adapter != "mysql"
  puts "This test only available for mysql adapter"
  exit 0
end
DatabaseSeeder.create

Spec.config_jennifer do |conf|
  conf.pool_size = POOL_SIZE
  conf.checkout_timeout = 1.0
  conf.retry_attempts = 1
  conf.retry_delay = 0.7
end

Spec.before_each do
  (Jennifer::Model::Base.models - [Jennifer::Migration::Version]).each(&.all.delete)
end

describe "Concurrent execution" do
  tread_count = POOL_SIZE + 1

  describe "Jennifer::Adapter::Base" do
    sleep_command =
      case Spec.adapter
      when "mysql"
        "SLEEP(#{TIME_TO_SLEEP})"
      when "postgres"
        "pg_sleep(#{TIME_TO_SLEEP})"
      else
        raise "Unknown adapter #{Spec.adapter}"
      end

    describe "#exec" do
      it "raises native db exception" do
        ch = Channel(String).new
        tread_count.times do
          spawn do
            begin
              puts Time.utc
              jennifer_adapter.exec("CREATE temporary table table1 select #{sleep_command} as col")
              puts "finish: #{Time.utc}"
              ch.send("")
            rescue e : Exception
              ch.send(e.class.to_s)
            end
          end
        end

        responses = (0...tread_count).map { ch.receive }
        responses.should contain("DB::PoolTimeout")
      end
    end

    describe "#query" do
      it "raises native db exception" do
        ch = Channel(String).new
        tread_count.times do
          spawn do
            begin
              jennifer_adapter.query("SELECT #{sleep_command}") do |rs|
                rs.each do
                  rs.columns.size.times do
                    rs.read
                  end
                end
              end

              ch.send("")
            rescue e : Exception
              puts e.inspect
              ch.send(e.class.to_s)
            end
          end
        end

        responses = (0...tread_count).map { ch.receive }
        responses.should contain("DB::PoolTimeout")
      end
    end

    describe "#scalar" do
      it "raises native db exception" do
        ch = Channel(String).new
        tread_count.times do
          spawn do
            begin
              jennifer_adapter.scalar("SELECT MAX(#{sleep_command})")
              ch.send("")
            rescue e : Exception
              ch.send(e.class.to_s)
            end
          end
        end

        responses = (0...tread_count).map { ch.receive }
        responses.should contain("DB::PoolTimeout")
      end
    end
  end
end
