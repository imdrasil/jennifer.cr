require "../db_command_interface"

module Jennifer
  module Mysql
    class CommandInterface < Adapter::DBCommandInterface
      def create_database
        raise AbstractMethod.new("create_database", self)
      end

      def drop_database
        raise AbstractMethod.new("drop_database", self)
      end

      def database_exists?
        raise AbstractMethod.new("database_exists?", self)
      end

      def generate_schema
        options = default_options
        options += ["--no-data", "--skip-lock-tables", config.db]
        command = Command.new(
          executable: "mysqldump",
          options: options,
          out_stream: "> #{config.structure_path}"
        )
        execute(command)
      end

      def load_schema
        options = default_options
        options += [config.db, "-B", "-s"]
        command = Command.new(
          executable: "mysql",
          options: options,
          in_stream: "cat #{config.structure_path} |"
        )
        execute(command)
      end

      private def default_options
        options = ["-h", config.host] of Command::Option
        options += ["-u", config.user] unless config.user.empty?
        options += ["--password='#{config.password}'"] unless config.password.empty?
        options += ["--port=#{config.port}"] if config.port > -1
        options
      end
    end
  end
end
