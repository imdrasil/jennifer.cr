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

      def generate_schema
        options = ["-U", config.user, "-d", config.db, "-h", config.host, "-s", "-f", config.structure_path] of Command::Option
        command = Command.new(
          executable: "pg_dump",
          options: options,
          inline_vars: default_env_variables
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
        {"PGPASSWORD" => config.password} of String => Command::Option
      end
    end
  end
end
