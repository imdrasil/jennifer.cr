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
        options = ["-u", config.user, "--no-data", "-h", config.host, "--skip-lock-tables", config.db]
        options += ["--password='#{config.password}'"] unless config.password.empty?
        options += ["--port=#{config.port}"] unless config.port.empty?
        command = Command.new(
          executable: "mysqldump",
          options: options,
          out_stream: "> #{config.structure_path}"
        )
        execute(command)
      end

      def load_schema
        options = ["-u", config.user, "-h", config.host, config.db, "-B", "-s"]
        options += ["--password='#{config.password}'"] unless config.password.empty?
        options += ["--port=#{config.port}"] unless config.port.empty?
        command = Command.new(
          executable: "mysql",
          options: options,
          in_stream: "cat #{config.structure_path} |"
        )
        execute(command)
      end
    end
  end
end
