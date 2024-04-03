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

  describe "generate:model" do
    it "generates model and migration classes" do
      clean do
        execute(
          "crystal spec/integration/sam/blank_application.cr",
          ["generate:model", "Article", "title:string", "text:text?"]
        ).should succeed

        model_path = "./scripts/models/article.cr"
        File.exists?(model_path).should be_true
        File.read(model_path).should eq(File.read("./spec/fixtures/generators/model.cr"))

        migration_path = Dir["./scripts/migrations/*.cr"].sort.last
        migration_path.should match(/\d{16}_create_articles\.cr/)
        Time.parse(File.basename(migration_path), "%Y%m%d%H%M%S%L", Time::Location.local)
          .should be_close(Time.local, 1.seconds)
        File.read(migration_path).should eq(File.read("./spec/fixtures/generators/create_migration.cr"))
      end
    end
  end

  describe "generate:migration" do
    it "generates migration class" do
      clean do
        execute(
          "crystal spec/integration/sam/blank_application.cr",
          ["generate:migration", "CreateArticles"]
        ).should succeed

        migration_path = Dir["./scripts/migrations/*.cr"].sort.last
        migration_path.should match(/\d{16}_create_articles\.cr/)
        Time.parse(File.basename(migration_path), "%Y%m%d%H%M%S%L", Time::Location.local)
          .should be_close(Time.local, 1.seconds)
        File.read(migration_path).should eq(File.read("./spec/fixtures/generators/migration.cr"))
      end
    end
  end
end
