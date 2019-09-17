require "../spec_helper"

describe Jennifer::Generators::Migration do
  described_class = Jennifer::Generators::Migration

  describe "#render" do
    timestamp = Time.local.to_s("%Y%m%d%H%M%S")
    args = Sam::Args.new({} of String => String, %w(CreateArticles))

    it "creates migration" do
      described_class.new(args).render
      expected_content = File.read("./spec/fixtures/generators/migration.cr")
      migration_path = Dir["./examples/migrations/*.cr"].sort.last

      migration_path.ends_with?("_create_articles.cr").should be_true
      File.basename(migration_path).starts_with?(timestamp).should be_true

      File.read(migration_path).should eq(expected_content)
    end
  end
end
