require "../../spec_helper"

postgres_only do
  class StubInterface < Jennifer::Postgres::CommandInterface
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

  describe Jennifer::Postgres::CommandInterface do
    described_class = Jennifer::Postgres::CommandInterface

    describe "#database_exists?" do
      it { described_class.new(Jennifer::Config.config).database_exists?.should be_true }

      it do
        config = Jennifer::Config.config
        config.db = "unexisting_test_database"
        described_class.new(config).database_exists?.should be_false
      end
    end

    describe "#drop_database" do
      it do
        config = build_config
        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.drop_database
        command.executable.should eq("dropdb")
        command.options.should eq([config.db, "-h", config.host, "-U", config.user])
        command.inline_vars.should eq({"PGPASSWORD" => config.password})
        command.in_stream.should eq("")
        command.out_stream.should eq("")
      end

      it "when user and password are blank" do
        config = build_config
        config.user = ""
        config.password = ""

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.drop_database
        command.options.should eq([config.db, "-h", config.host])
        command.inline_vars.should be_empty
      end

      it "with a custom port" do
        config = build_config
        config.port = 100

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.drop_database
        command.options.should eq([config.db, "-h", config.host, "-U", config.user])
        command.inline_vars.should eq({"PGPASSWORD" => config.password, "PGPORT" => "100"})
      end
    end

    describe "#create_database" do
      it do
        config = build_config
        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.create_database
        command.executable.should eq("createdb")
        command.options.should eq([config.db, "-h", config.host, "-U", config.user, "-O", config.user])
        command.inline_vars.should eq({"PGPASSWORD" => config.password})
        command.in_stream.should eq("")
        command.out_stream.should eq("")
      end

      it "when user and password are blank" do
        config = build_config
        config.user = ""
        config.password = ""

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.create_database
        command.options.should eq([config.db, "-h", config.host])
        command.inline_vars.should be_empty
      end

      it "with a custom port" do
        config = build_config
        config.port = 100

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.create_database
        command.options.should eq([config.db, "-h", config.host, "-U", config.user, "-O", config.user])
        command.inline_vars.should eq({"PGPORT" => "100", "PGPASSWORD" => config.password})
      end
    end

    describe "#generate_schema" do
      it do
        config = build_config
        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.generate_schema
        command.executable.should eq("pg_dump")
        command.options.should eq(["-h", config.host, "-U", config.user, "-d", config.db, "-s"])
        command.inline_vars.should eq({"PGPASSWORD" => config.password})
        command.in_stream.should eq("")
        command.out_stream.should eq("> #{config.structure_path}")
      end

      it "when user and password are blank" do
        config = build_config
        config.user = ""
        config.password = ""

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.generate_schema
        command.options.should eq(["-h", config.host, "-d", config.db, "-s"])
        command.inline_vars.should be_empty
      end

      it "with a custom port" do
        config = build_config
        config.port = 100

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.generate_schema
        command.inline_vars.should eq({"PGPORT" => "100", "PGPASSWORD" => config.password})
      end
    end

    describe "#load_schema" do
      it do
        config = build_config
        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.load_schema
        command.executable.should eq("psql")
        command.options.should eq([
          "-h", config.host, "-U", config.user, "-d", config.db, "-a", "-f", config.structure_path,
        ])
        command.inline_vars.should eq({"PGPASSWORD" => config.password})
        command.in_stream.should eq("")
        command.out_stream.should eq("")
      end

      it "when user and password are blank" do
        config = build_config
        config.user = ""
        config.password = ""

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.load_schema
        command.options.should eq(["-h", config.host, "-d", config.db, "-a", "-f", config.structure_path])
        command.inline_vars.should be_empty
      end

      it "with a custom port" do
        config = build_config
        config.port = 100

        interface = StubInterface.new(Jennifer::Config.config)
        command = interface.load_schema
        command.inline_vars.should eq({"PGPORT" => "100", "PGPASSWORD" => config.password})
      end
    end
  end
end
