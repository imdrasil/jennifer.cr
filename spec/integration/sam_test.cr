require "./spec_helper.cr"
require "spec"

DEFAULT_DB = "jennifer_integration_test"

def execute(command, options)
  io = IO::Memory.new

  status = Process.run("#{command} \"${@}\"", options, shell: true, output: io, error: io).exit_status
  {status, io.to_s}
end

def clean(db = DEFAULT_DB)
  yield
ensure
  config = Jennifer::Config
  command =
    case Spec.adapter
    when "postgres"
      user = ENV["DB_USER"]? || "developer"
      password = ENV["DB_PASSWORD"]? || "1qazxsw2"
      "PGPASSWORD=#{password} dropdb #{db} -U#{user}"
    when "mysql"
      user = ENV["DB_USER"]? || "root"
      password = ENV["DB_PASSWORD"]?
      common_command = "echo \"drop database #{db};\" | mysql -u#{user}"
      common_command += " -p#{password}" if password
      common_command
    else
      raise "Unknown adapter"
    end
  Process.run(command, shell: true)
end

def create_db(db = DEFAULT_DB)
  config = Jennifer::Config
  command =
    case Spec.adapter
    when "postgres"
      user = ENV["DB_USER"]? || "developer"
      password = ENV["DB_PASSWORD"]? || "1qazxsw2"
      "PGPASSWORD=#{password} createdb #{db} -U#{user}"
    when "mysql"
      user = ENV["DB_USER"]? || "root"
      password = ENV["DB_PASSWORD"]?
      common_command = "echo \"create database #{db};\" | mysql -u#{user}"
      common_command += " -p#{password}" if password
      common_command
    else
      raise "Unknown adapter"
    end
  Process.run(command, shell: true)
end

# NOTE: drop existing db before running tests
clean {}

describe "Blank application" do
  describe "db:create" do
    it do
      clean do
        execute("crystal spec/integration/sam/blank_application.cr", ["db:create"])[0].should eq(0)
      end
    end
  end

  describe "db:drop" do
    it do
      clean do
        create_db
        execute("crystal spec/integration/sam/blank_application.cr", ["db:drop"])[0].should eq(0)
      end
    end
  end

  describe "db:migrate" do
    it do
      clean do
        create_db
        execute("crystal spec/integration/sam/blank_application.cr", ["db:migrate"])[0].should eq(0)
      end
    end
  end
end
