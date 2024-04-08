require "../../spec_helper"

mysql_only do
  class StubInterface < Jennifer::Mysql::CommandInterface
    def execute(command)
      command
    end
  end

  def build_config
    config = Jennifer::Config.config
    config.password = "password"
    config.user = "user"
    config
  end

  describe Jennifer::Mysql::CommandInterface do
    describe "#generate_schema" do
      it do
        config = build_config
        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.generate_schema
        command.executable.should eq("mysqldump")
        command.options.should eq([
          "-h", config.host, "-u", config.user, "--password='#{config.password}'",
          "--no-data", "--skip-lock-tables", config.db,
        ])
        command.inline_vars.empty?.should be_true
        command.in_stream.should eq("")
        command.out_stream.should eq("> #{config.structure_path}")
      end

      it "when user and password are blank" do
        config = build_config
        config.user = ""
        config.password = ""

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.generate_schema
        command.options.should eq(["-h", config.host, "--no-data", "--skip-lock-tables", config.db])
      end

      it "with a custom port" do
        config = build_config
        config.port = 100

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.generate_schema
        command.options.should eq([
          "-h", config.host, "-u", config.user, "--password='#{config.password}'", "--port=#{config.port}",
          "--no-data", "--skip-lock-tables", config.db,
        ])
      end
    end

    describe "#load_schema" do
      it do
        config = build_config
        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.load_schema
        command.executable.should eq("mysql")
        command.options.should eq([
          "-h", config.host, "-u", config.user, "--password='#{config.password}'", config.db, "-B", "-s",
        ])
        command.inline_vars.empty?.should be_true
        command.in_stream.should eq("cat #{config.structure_path} |")
        command.out_stream.should eq("")
      end

      it "when user and password are blank" do
        config = build_config
        config.user = ""
        config.password = ""

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.load_schema
        command.options.should eq(["-h", config.host, config.db, "-B", "-s"])
      end

      it "with a custom port" do
        config = build_config
        config.port = 100

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.load_schema
        command.options.should eq([
          "-h", config.host, "-u", config.user, "--password='#{config.password}'", "--port=#{config.port}",
          config.db, "-B", "-s",

        ])
      end
    end
  end
end
