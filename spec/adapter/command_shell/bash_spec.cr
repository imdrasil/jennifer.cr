require "./spec_helper"

describe Jennifer::Adapter::Bash do
  described_class = Jennifer::Adapter::Bash

  describe "#execute" do
    context "with environment variables" do
      it do
        stub_command_shell
        shell = described_class.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          inline_vars: { "var1" => "val1", "var2" => "val2" }
        )
        shell.execute(c).should be_executed_as("var1=val1 var2=val2 ls \"${@}\"", %w())
      end
    end

    context "with incoming stream" do
      it do
        stub_command_shell
        shell = described_class.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          in_stream: "cat asd |"
        )
        shell.execute(c).should be_executed_as("cat asd | ls \"${@}\"", %w())
      end
    end

    context "with outgoing stream" do
      it do
        stub_command_shell
        shell = described_class.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          out_stream: "> asd"
        )
        shell.execute(c).should be_executed_as("ls \"${@}\" > asd", %w())
      end
    end

    context "with options" do
      it do
        stub_command_shell
        shell = described_class.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          options: ["asd"]
        )
        shell.execute(c).should be_executed_as("ls \"${@}\"", ["asd"])
      end
    end

    context "with sudo stream" do
      it do
        stub_command_shell
        Jennifer::Config.command_shell_sudo = true
        shell = Jennifer::Adapter::Bash.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          in_stream: "cat asd |"
        )
        shell.execute(c).should be_executed_as("cat asd | sudo ls \"${@}\"", %w())
      end
    end
  end
end
