require "./spec_helper"

describe Jennifer::Config do
  describe "asd" do
    it "test" do
      begin
        Jennifer::Config.read("./spec/fixtures/database.yml")
        Jennifer::Config.config.db.should eq("jennifer_develop")
      ensure
        Jennifer::Config.config.db = "jennifer_test"
      end
    end
  end
end
