# require "./spec_helper"

def prepare_docker_config
  Jennifer::Config.configure do |conf|
    conf.docker_container = "some_container"
  end
  Jennifer::Adapter::Docker.new(Jennifer::Config.instance)
end

describe Jennifer::Adapter::Docker do
  describe "#execute" do
    context "with environment variables" do
      it do
        stub_command_shell
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          inline_vars: {"var1" => "val1", "var2" => "val2"}
        )
        shell.execute(c).should be_executed_as("docker exec -i -e var1=val1 -e var2=val2 some_container ls \"${@}\"", %w())
      end
    end

    context "with incoming stream" do
      it do
        stub_command_shell
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          in_stream: "cat asd |"
        )
        shell.execute(c).should be_executed_as("cat asd | docker exec -i some_container ls \"${@}\"", %w())
      end
    end

    context "with outgoing stream" do
      it do
        stub_command_shell
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          out_stream: "> asd"
        )
        shell.execute(c).should be_executed_as("docker exec -i some_container ls \"${@}\" > asd", %w())
      end
    end

    context "with options" do
      it do
        stub_command_shell
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          options: ["asd"]
        )
        shell.execute(c).should be_executed_as("docker exec -i some_container ls \"${@}\"", ["asd"])
      end

      context "with environment variables" do
        it do
          stub_command_shell
          shell = prepare_docker_config
          c = Jennifer::Adapter::ICommandShell::Command.new(
            executable: "ls",
            options: ["asd"],
            inline_vars: {"var1" => "val1"}
          )
          shell.execute(c).should be_executed_as("docker exec -i -e var1=val1 some_container ls \"${@}\"", ["asd"])
        end
      end
    end

    context "with sudo" do
      it do
        stub_command_shell
        Jennifer::Config.command_shell_sudo = true
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          in_stream: "cat asd |"
        )
        shell.execute(c).should be_executed_as("cat asd | sudo docker exec -i some_container ls \"${@}\"", %w())
      end
    end
  end
end
