require "../../spec_helper"

describe Jennifer::Adapter::ICommandShell::Command do
  described_class = Jennifer::Adapter::ICommandShell::Command

  describe ".new" do
    context "with all arguments" do
      it do
        command = described_class.new("some_executable", ["option1"], {"var" => "value"}, "car test |", " > test")
        command.executable.should eq("some_executable")
        command.options.should eq(["option1"])
        command.inline_vars.should eq({"var" => "value"})
        command.in_stream.should eq("car test |")
        command.out_stream.should eq(" > test")
      end
    end

    pending "with required arguments only"
  end

  pending "#in_stream?"
  pending "#out_stream?"
  pending "#inline_vars?"
end
