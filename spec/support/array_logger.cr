require "logger"

class ArrayLogger < Logger
  property silent : Bool
  getter container = [] of {sev: String, msg: String}

  def initialize(@io : IO?, @silent = true)
    @level = Severity::INFO
    @formatter = DEFAULT_FORMATTER
    @progname = ""
    @closed = false
    @mutex = Mutex.new
    @formatter = Formatter.new do |_, _, _, msg, output|
      output << msg
    end
  end

  def clear
    @container.clear
  end

  private def write(severity, datetime, progname, message)
    progname_to_s = progname.to_s
    message_to_s = message.to_s
    @mutex.synchronize do
      new_message = String.build do |io|
        formatter.call(severity, datetime, progname_to_s, message_to_s, io)
      end
      @container << {sev: severity.to_s, msg: new_message}
    end
  end
end
