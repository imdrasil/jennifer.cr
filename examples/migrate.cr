require "../src/jennifer"
require "./migrations/*"

Jennifer::Config.configure do |conf|
  conf.host = "localhost"
  conf.user = "root"
  conf.password = ""
  conf.adapter = "mysql"
  conf.db = "crystal"
  conf.migration_files_path = "./examples/migrations"
end

# require "../src/make"
require "sam"
require "../src/sam"
Sam.help
