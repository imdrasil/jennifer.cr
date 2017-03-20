# require "../src/jennifer/adapter/mysql"
require "../src/jennifer"
require "../src/jennifer/adapter/postgres"

adapter = "postgres"
# adapter = "mysql"

Jennifer::Config.configure do |conf|
  conf.host = "localhost"
  conf.adapter = adapter
  conf.migration_files_path = "./examples/migrations"

  case adapter
  when "mysql"
    conf.user = "root"
    conf.password = ""
    conf.db = "prequel_test"
  when "postgres"
    conf.user = "developer"
    conf.password = "1qazxsw2"
    conf.db = "crystal_test"
  when "sqlite3"
    conf.host = "./spec/db"
    conf.db = "jennifer_test.db"
  end
end
