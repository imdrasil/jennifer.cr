require "../spec/config"
require "../spec/models"
require "./migrations/*"
require "sam"
require "../src/jennifer/sam"

Jennifer::Config.configure do |conf|
  # conf.logger = Logger.new(STDOUT)
  conf.logger.level = Logger::DEBUG
  # conf.logger.level = Logger::ERROR
end

Sam.namespace "script" do
  task "drop_models" do
    Jennifer::Model::Base.models.select(&.has_table?).each(&.all.delete)
  end
end

Sam.help
