require "../shared_helpers"
require "sam"
require "../../../src/jennifer/sam"

Jennifer::Config.configure do |conf|
  conf.read("./scripts/database.yml", Spec.adapter)
  conf.logger.level = :debug
  conf.adapter = Spec.adapter
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

Log.setup "db", :debug, Log::IOBackend.new(formatter: Jennifer::Adapter::DBFormatter)

Sam.help
