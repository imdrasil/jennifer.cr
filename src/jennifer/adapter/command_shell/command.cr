module Jennifer
  module Adapter
    abstract class ICommandShell
      class Command
        class Failed < BaseException
          def initialize(code, io)
            @message = "DB command interface exit code #{code}: #{io}"
          end
        end

        alias Option = String

        property executable : String,
          options : Array(Option),
          inline_vars : Hash(String, Option),
          in_stream : String,
          out_stream : String

        def initialize(@executable, @options = [] of Option, @inline_vars = {} of String => Option, @in_stream = "", @out_stream = "")
        end

        def in_stream?
          !@in_stream.empty?
        end

        def out_stream?
          !@out_stream.empty?
        end

        def inline_vars?
          !@inline_vars.empty?
        end
      end
    end
  end
end
