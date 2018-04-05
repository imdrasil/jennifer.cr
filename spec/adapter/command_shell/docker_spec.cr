require "./spec_helper"

def prepare_docker_config
  Jennifer::Config.configure do |conf|
    conf.docker_container = "some_container"
  end
  Jennifer::Adapter::Docker.new(Jennifer::Config.instance)
end

describe Jennifer::Adapter::Docker do
  described_class = Jennifer::Adapter::Docker

  describe "#execute" do
    context "with environment variables" do
      it do
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          inline_vars: { "var1" => "val1", "var2" => "val2" }
        )
        res = shell.execute(c)
        res[0].should eq("docker exec -i -e var1=val1 -e var2=val2 some_container ls \"${@}\"")
        res[1].empty?.should be_true
      end
    end

    context "with incoming stream" do
      it do
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          in_stream: "cat asd |"
        )
        res = shell.execute(c)
        res[0].should eq("cat asd | docker exec -i some_container ls \"${@}\"")
        res[1].empty?.should be_true
      end
    end

    context "with outgoing stream" do
      it do
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          out_stream: "> asd"
        )
        res = shell.execute(c)
        res[0].should eq("docker exec -i some_container ls \"${@}\" > asd")
        res[1].empty?.should be_true
      end
    end

    context "with options" do
      it do
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          options: ["asd"]
        )
        res = shell.execute(c)
        res[0].should eq("docker exec -i some_container ls \"${@}\"")
        res[1].should eq(["asd"])
      end

      context "with environment variables" do
        it do
          shell = prepare_docker_config
          c = Jennifer::Adapter::ICommandShell::Command.new(
            executable: "ls",
            options: ["asd"],
            inline_vars: { "var1" => "val1"}
          )
          res = shell.execute(c)
          res[0].should eq("docker exec -i -e var1=val1 some_container ls \"${@}\"")
          res[1].should eq(["asd"])
        end
      end
    end

    context "with sudo" do
      it do
        Jennifer::Config.command_shell_sudo = true
        shell = prepare_docker_config
        c = Jennifer::Adapter::ICommandShell::Command.new(
          executable: "ls",
          in_stream: "cat asd |"
        )
        res = shell.execute(c)
        res[0].should eq("cat asd | sudo docker exec -i some_container ls \"${@}\"")
        res[1].empty?.should be_true
      end
    end
  end
end
