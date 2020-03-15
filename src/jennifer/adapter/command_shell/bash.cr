module Jennifer
  module Adapter
    class Bash < ICommandShell
      def execute(command) : NamedTuple
        command_string = String.build do |io|
          add_env_vars(io, command)
          add_income_stream(io, command)
          io << "sudo " if config.command_shell_sudo
          io << command.executable
          io << " "
          io << OPTIONS_PLACEHOLDER
          add_outcome_stream(io, command)
        end
        invoke(command_string, command.options)
      end

      private def add_income_stream(io, command)
        return unless command.in_stream?
        io << command.in_stream
        io << " "
      end

      private def add_outcome_stream(io, command)
        return unless command.out_stream?
        io << " "
        io << command.out_stream
      end

      private def add_env_vars(io, command)
        return unless command.inline_vars?
        io << command.inline_vars.join(" ") { |k, v| "#{k}=#{v}" }
        io << " "
      end
    end

    DBCommandInterface.register_shell("bash", Bash)
  end
end
