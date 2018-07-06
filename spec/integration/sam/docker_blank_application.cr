require "../shared_helpers"
require "sam"
require "../../../src/jennifer/sam"

raise "Currently Docker related integration tests are available only for mysql" if Spec.adapter != "mysql"

Jennifer::Config.configure do |conf|
  conf.logger.level = Logger::DEBUG
  conf.host = "127.0.0.1"
  conf.adapter = Spec.adapter
  conf.migration_files_path = "./examples/migrations"
  conf.db = DEFAULT_DB
  conf.port = 11009

  # NOTE: currently related tests are available only for local run
  conf.docker_container = DEFAULT_DOCKER_CONTAINER
  conf.command_shell = "docker"
  conf.command_shell_sudo = true

  case Spec.adapter
  when "mysql"
    conf.user = ENV["DB_USER"]? || "root"
    conf.password = ""
  when "postgres"
    conf.user = ENV["DB_USER"]? || "developer"
    conf.password = ENV["DB_PASSWORD"]? || "1qazxsw2"
  end
end

Sam.help
