require "./spec_helper"

describe Jennifer::Config do
  describe "::read" do
    it "reades data from yaml file" do
      begin
        Jennifer::Config.read("./spec/fixtures/database.yml")
        Jennifer::Config.config.db.should eq("jennifer_develop")
      ensure
        Jennifer::Config.config.db = "jennifer_test"
      end
    end
  end
end
