require "./command_shell/i_command_shell"

module Jennifer
  module Adapter
    abstract class DBCommandInterface
      alias Command = ::Jennifer::Adapter::ICommandShell::Command

      getter config : Config

      @_shell : ICommandShell?

      @@shells = {} of String => ICommandShell.class

      def initialize(@config)
      end

      abstract def drop_database
      abstract def create_database
      abstract def generate_schema
      abstract def load_schema
      abstract def database_exists?

      def execute(command)
        shell.execute(command)
      end

      def shell
        @_shell ||= DBCommandInterface.build_shell(config)
      end

      def self.build_shell(config)
        @@shells[config.command_shell].new(config)
      rescue e : KeyError
        raise BaseException.new("Unregistered command shell: #{config.command_shell}")
      end

      def self.register_shell(name, klass)
        @@shells[name] = klass
      end
    end
  end
end

require "./command_shell/bash"
require "./command_shell/docker"
