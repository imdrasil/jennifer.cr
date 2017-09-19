require "../spec/config"
require "../spec/models"
require "./migrations/*"
require "sam"
require "../src/jennifer/sam"

Sam.namespace "script" do
  task "drop_models" do
    Jennifer::Model::Base.models.select(&.has_table?).each(&.all.delete)
  end
end

Sam.help
