require "../shared_helpers"
require "sam"
require "../../../src/jennifer/sam"

Spec.config_jennifer do |conf|
  conf.logger.level = :debug
end

Log.setup "db", :debug, Log::IOBackend.new(formatter: Jennifer::Adapter::DBFormatter)

Sam.help
