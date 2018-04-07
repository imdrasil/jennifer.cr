require "../../spec_helper"

class Jennifer::Adapter::ICommandShell
  private def invoke(command_string, options)
    {command_string, options}
  end
end
