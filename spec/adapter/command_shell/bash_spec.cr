require "./spec_helper"

describe Jennifer::Adapter::Bash do
  described_class = Jennifer::Adapter::Bash

  describe "#execute" do
    context "with environment variables" do
      it do
        shell = described_class.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          inline_vars: { "var1" => "val1", "var2" => "val2" }
        )
        res = shell.execute(c)
        res[0].should eq("var1=val1 var2=val2 ls \"${@}\"")
        res[1].empty?.should be_true
      end
    end

    context "with incoming stream" do
      it do
        shell = described_class.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          in_stream: "cat asd |"
        )
        res = shell.execute(c)
        res[0].should eq("cat asd | ls \"${@}\"")
        res[1].empty?.should be_true
      end
    end

    context "with outgoing stream" do
      it do
        shell = described_class.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          out_stream: "> asd"
        )
        res = shell.execute(c)
        res[0].should eq("ls \"${@}\" > asd")
        res[1].empty?.should be_true
      end
    end

    context "with options" do
      it do
        shell = described_class.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          options: ["asd"]
        )
        res = shell.execute(c)
        res[0].should eq("ls \"${@}\"")
        res[1].should eq(["asd"])
      end
    end

    context "with sudo stream" do
      it do
        shell = described_class.new(Jennifer::Config.instance)
        Jennifer::Config.command_shell_sudo = true
        shell = Jennifer::Adapter::Bash.new(Jennifer::Config.instance)
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          in_stream: "cat asd |"
        )
        res = shell.execute(c)
        res[0].should eq("cat asd | sudo ls \"${@}\"")
        res[1].empty?.should be_true
      end
    end
  end
end
