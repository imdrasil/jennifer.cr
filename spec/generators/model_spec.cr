require "../spec_helper"

describe Jennifer::Generators::Model do
  described_class = Jennifer::Generators::Model

  describe "#render" do
    timestamp = Time.local.to_s("%Y%m%d%H%M%S%L")[0...-5]

    context "with common fields only" do
      args = Sam::Args.new({} of String => String, %w(Article title:string text:text?))

      it "creates model" do
        described_class.new(args).render
        expected_content = File.read("./spec/fixtures/generators/model.cr")
        model_path = "./examples/models/article.cr"
        File.exists?(model_path).should be_true
        File.read(model_path).should eq(expected_content)
      end

      it "creates migration" do
        described_class.new(args).render
        expected_content = File.read("./spec/fixtures/generators/create_migration.cr")
        migration_path = Dir["./examples/migrations/*.cr"].sort.last

        migration_path.should match(/\d{16}_create_articles\.cr/)
        File.basename(migration_path).starts_with?(timestamp).should be_true
        File.read(migration_path).should eq(expected_content)
      end
    end

    context "with references" do
      args = Sam::Args.new({} of String => String, %w(Article title:string text:text? author:reference))

      it "creates model" do
        described_class.new(args).render
        expected_content = File.read("./spec/fixtures/generators/model_with_references.cr")
        model_path = "./examples/models/article.cr"
        File.exists?(model_path).should be_true
        File.read(model_path).should eq(expected_content)
      end

      it "creates migration" do
        described_class.new(args).render
        expected_content = File.read("./spec/fixtures/generators/create_migration_with_references.cr")
        migration_path = Dir["./examples/migrations/*.cr"].sort.last

        migration_path.ends_with?("_create_articles.cr").should be_true
        File.basename(migration_path).starts_with?(timestamp).should be_true

        File.read(migration_path).should eq(expected_content)
      end
    end
  end
end
