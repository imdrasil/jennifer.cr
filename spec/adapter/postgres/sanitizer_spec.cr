require "../../spec_helper"

postgres_only do
  describe Jennifer::Adapter::Sanitizer do
    driver = Jennifer::Adapter::SqlGenerator

    context "String" do
      it "escapes '" do
        driver.escape("text'").should eq("'text\\''")
      end
    end
  end
end
