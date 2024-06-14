require "./command"

module Jennifer
  module Adapter
    abstract class ICommandShell
      OPTIONS_PLACEHOLDER = {% flag?(:win32) ? "" : %("${@}") %}
      SUDO                = {% flag?(:win32) ? "" : "sudo" %}
      abstract def execute(command) : NamedTuple

      getter config : Config

      def initialize(@config)
      end

      private def invoke(command_string, options) : NamedTuple
        io = IO::Memory.new

        result = {% if flag?(:win32) %}
            Process.run("cmd", ["/c", command_string] + options, output: io, error: io)
          {% else %}
            Process.run(command_string, options, shell: true, output: io, error: io)
          {% end %}

        raise Command::Failed.new(result.exit_code, io) if result.exit_code != 0
        {status: result, output: io}
      end
    end
  end
end
