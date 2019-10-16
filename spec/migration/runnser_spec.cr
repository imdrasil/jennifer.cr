require "../spec_helper"

module Jennifer::Migration::Runner
  def self.reset_pending_versions
    @@pending_versions.clear
  end
end

describe Jennifer::Migration::Runner do
  described_class = Jennifer::Migration::Runner

  describe ".pending_migration?" do
    it do
      described_class.reset_pending_versions
      described_class.pending_migration?.should be_false
    end

    it do
      described_class.reset_pending_versions
      Jennifer::Migration::Version.all.where { _version == "20170119011451314" }.destroy
      described_class.pending_migration?.should be_true
    end
  end
end
