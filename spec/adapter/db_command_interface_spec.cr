require "../spec_helper"

describe Jennifer::Adapter::DBCommandInterface do
  described_class = Jennifer::Adapter::DBCommandInterface

  describe ".build_shell" do
    it do
      Jennifer::Config.config.command_shell = "bash"
      described_class.build_shell(Jennifer::Config.config).is_a?(Jennifer::Adapter::Bash).should be_true
    end

    it do
      Jennifer::Config.config.command_shell = "docker"
      described_class.build_shell(Jennifer::Config.config).is_a?(Jennifer::Adapter::Docker).should be_true
    end

    it do
      Jennifer::Config.config.command_shell = "unknown"
      expect_raises(Jennifer::BaseException) { described_class.build_shell(Jennifer::Config.config) }
    end
  end
end
