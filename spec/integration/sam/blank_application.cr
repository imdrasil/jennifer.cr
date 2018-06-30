require "../shared_helpers"
require "sam"
require "../../../src/jennifer/sam"

Jennifer::Config.configure do |conf|
  conf.logger.level = Logger::DEBUG
  conf.host = "localhost"
  conf.adapter = Spec.adapter
  conf.migration_files_path = "./examples/migrations"
  conf.db = DEFAULT_DB

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
