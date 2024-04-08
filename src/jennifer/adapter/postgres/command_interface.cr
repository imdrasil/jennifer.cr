require "../db_command_interface"

module Jennifer
  module Postgres
    class CommandInterface < Adapter::DBCommandInterface
      def drop_database
        options = [config.db] of Command::Option
        options += default_options
        command = Command.new(
          executable: "dropdb",
          options: options,
          inline_vars: default_env_variables
        )
        execute(command)
      end

      def create_database
        options = [config.db] of Command::Option
        options += default_options
        options += ["-O", config.user] unless config.user.empty?
        command = Command.new(
          executable: "createdb",
          options: options,
          inline_vars: default_env_variables
        )
        execute(command)
      end

      def database_exists? : Bool
        options = default_options
        options += ["-l"] of Command::Option
        command = Command.new(
          executable: "psql",
          options: options,
          inline_vars: default_env_variables
        )
        execute(command)[:output].to_s.split("\n")[2..-1].any?(&.[](/([^|]*)? |/).strip.==(config.db))
      end

      def generate_schema
        options = default_options
        options += ["-d", config.db, "-s"]
        command = Command.new(
          executable: "pg_dump",
          options: options,
          inline_vars: default_env_variables,
          out_stream: "> #{config.structure_path}"
        )
        execute(command)
      end

      def load_schema
        options = default_options
        options += ["-d", config.db, "-a", "-f", config.structure_path] of Command::Option
        command = Command.new(
          executable: "psql",
          options: options,
          inline_vars: default_env_variables
        )
        execute(command)
      end

      private def default_env_variables
        env = {} of String => Command::Option
        env["PGPASSWORD"] = config.password unless config.password.blank?
        env["PGPORT"] = config.port.to_s unless config.port == -1
        env
      end

      private def default_options
        options = ["-h", config.host] of Command::Option
        options += ["-U", config.user] unless config.user.empty?
        options
      end
    end
  end
end
