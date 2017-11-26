require "../config"
require "sam"
require "../../src/jennifer/sam"

Jennifer::Config.configure do |conf|
  conf.host = "localhost"
  conf.adapter = "postgres"
  conf.db = "jennifer-bug"
  conf.migration_files_path = "./migrations"
end

Sam.help
