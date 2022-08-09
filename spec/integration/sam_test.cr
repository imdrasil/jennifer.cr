require "./spec_helper"

# drop existing db before running tests
DatabaseSeeder.drop

describe "Blank application" do
  describe "db:create" do
    it do
      clean do
        execute("crystal spec/integration/sam/blank_application.cr", ["db:create"]).should succeed
      end
    end

    context "when database already exists" do
      it do
        clean do
          execute("crystal spec/integration/sam/blank_application.cr", ["db:create"]).should succeed
          execute("crystal spec/integration/sam/blank_application.cr", ["db:create"]).should succeed
        end
      end
    end
  end

  describe "db:drop" do
    it do
      clean do
        DatabaseSeeder.create
        execute("crystal spec/integration/sam/blank_application.cr", ["db:drop"]).should succeed
      end
    end
  end

  describe "db:migrate" do
    it do
      clean do
        DatabaseSeeder.create
        execute("crystal spec/integration/sam/blank_application.cr", ["db:migrate"]).should succeed
      end
    end
  end
end
