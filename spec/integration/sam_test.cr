require "./spec_helper"
require "./shared_helpers"

# drop existing db before running tests
DatabaseSeeder.drop

describe "Blank application" do
  describe "db:create" do
    it do
      clean do
        execute("crystal spec/integration/sam/blank_application.cr", ["db:create"]).should succeed
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

  {% if env("DOCKER") == "1" %}
    context "with dockerize mysql db" do
      it do
        clean(:docker) do
          execute("crystal spec/integration/sam/docker_blank_application.cr", ["db:create"]).should succeed
        end
      end
    end
  {% end %}
end
