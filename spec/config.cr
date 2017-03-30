# require "../src/jennifer/adapter/mysql"
require "../src/jennifer/adapter/postgres"
require "../src/jennifer"

adapter = "postgres"
# adapter = "mysql"

Jennifer::Config.configure do |conf|
  conf.logger.level = Logger::ERROR
  conf.host = "localhost"
  conf.adapter = adapter
  conf.migration_files_path = "./examples/migrations"

  case adapter
  when "mysql"
    conf.user = "root"
    conf.password = ""
    conf.db = "jennifer_test"
  when "postgres"
    conf.user = ENV["PG_USER"]? || "developer"
    conf.password = ENV["PG_PASSWORD"]? || "1qazxsw2"
    conf.db = "jennifer_test"
  when "sqlite3"
    conf.host = "./spec/db"
    conf.db = "jennifer_test.db"
  end
end
