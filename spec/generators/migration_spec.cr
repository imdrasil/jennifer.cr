require "../spec_helper"

describe Jennifer::Generators::Migration do
  described_class = Jennifer::Generators::Migration

  describe "#render" do
    args = Sam::Args.new({} of String => String, %w(CreateArticles))

    it "creates migration" do
      described_class.new(args.raw).render
      expected_content = File.read("./spec/fixtures/generators/migration.cr")
      migration_path = Dir["./scripts/migrations/*.cr"].sort.last

      migration_path.should match(/\d{16}_create_articles\.cr/)
      Time.parse(File.basename(migration_path), "%Y%m%d%H%M%S%L", Time::Location.local).should be_close(Time.local, 1.seconds)
      File.read(migration_path).should eq(expected_content)
    end
  end
end
