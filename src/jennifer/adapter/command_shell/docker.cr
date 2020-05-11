module Jennifer::Adapter
  class Docker < ICommandShell
    def execute(command) : NamedTuple
      command_string = String.build do |io|
        add_income_stream(io, command)
        io << "sudo " if config.command_shell_sudo
        io << "docker exec -i "
        add_inline_vars(io, command)
        io << config.docker_container
        io << " "
        io << config.docker_source_location
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

    private def add_inline_vars(io, command)
      return unless command.inline_vars?
      command.inline_vars.each do |name, value|
        io << "-e "
        io << name
        io << "="
        io << value
        io << " "
      end
    end
  end

  DBCommandInterface.register_shell("docker", Docker)
end
