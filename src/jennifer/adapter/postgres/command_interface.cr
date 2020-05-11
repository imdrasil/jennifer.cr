require "../db_command_interface"

module Jennifer
  module Postgres
    class CommandInterface < Adapter::DBCommandInterface
      def drop_database
        options = [config.db, "-h", config.host, "-U", config.user] of Command::Option
        command = Command.new(
          executable: "dropdb",
          options: options,
          inline_vars: default_env_variables
        )
        execute(command)
      end

      def create_database
        options = [config.db, "-O", config.user, "-h", config.host, "-U", config.user] of Command::Option
        command = Command.new(
          executable: "createdb",
          options: options,
          inline_vars: default_env_variables
        )
        execute(command)
      end

      def database_exists? : Bool
        options = ["-U", config.user, "-h", config.host, "-l"] of Command::Option
        command = Command.new(
          executable: "psql",
          options: options,
          inline_vars: default_env_variables
        )
        execute(command)[:output].to_s.split("\n")[2..-1].any?(&.[](/([^|]*)? |/).strip.==(config.db))
      end

      def generate_schema
        options = ["-U", config.user, "-d", config.db, "-h", config.host, "-s"] of Command::Option
        command = Command.new(
          executable: "pg_dump",
          options: options,
          inline_vars: default_env_variables,
          out_stream: "> #{config.structure_path}"
        )
        execute(command)
      end

      def load_schema
        options = ["-U", config.user, "-d", config.db, "-h", config.host, "-a", "-f", config.structure_path] of Command::Option
        command = Command.new(
          executable: "psql",
          options: options,
          inline_vars: default_env_variables
        )
        execute(command)
      end

      private def default_env_variables
        env = {"PGPASSWORD" => config.password} of String => Command::Option
        env["PGPORT"] = config.port.to_s unless config.port == -1
        env
      end
    end
  end
end
