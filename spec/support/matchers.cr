module Spec
  # :nodoc:
  struct BeValidExpectation
    def match(object)
      object.valid?
    end

    def failure_message(object)
      "Expected: #{object.inspect} to be valid"
    end

    def negative_failure_message(object)
      "Expected: #{object.inspect} not to be valid"
    end
  end

  struct AttributeValidationExpectation
    @error_message : String?

    def initialize(@attr : Symbol)
    end

    def with(msg)
      @error_message = msg
      self
    end

    def match(object)
      raise ArgumentError.new("validation message should be specified.") if @error_message.nil?
      _error_message = @error_message.not_nil!

      object.validate!
      object.errors[@attr].includes?(@error_message)
    end

    def failure_message(object)
      "Expected: #{object.inspect} to have error message: "\
      "'#{@error_message}', but got: '#{object.errors[@attr].inspect}'"
    end

    def negative_failure_message(object)
      "Expected: #{object.inspect} not to have error message: "\
      "'#{@error_message}', but got: '#{object.errors[@attr].inspect}'"
    end
  end

  struct CommandSucceedExpectation
    def match(tuple)
      tuple[0] == 0
    end

    def failure_message(tuple)
      "Expected command to return status 0, got #{tuple[0]}.\nError message:\n#{tuple[1]}"
    end

    def negative_failure_message(tuple)
      "Expected command to return non 0 status, got #{tuple[0]}.\nError message:\n#{tuple[1]}"
    end
  end

  module Expectations
    macro expect_queries_to_be_executed(amount)
      %count = query_count
      {{yield}}
      %executed_amount = query_count - %count
      if %executed_amount != {{amount}}
        fail "Expected {{amount}} queries to be executed but #{%executed_amount} were."
      end
    end

    macro expect_query_silence
      expect_queries_to_be_executed(0) do
        {{yield}}
      end
    end

    def be_valid
      BeValidExpectation.new
    end

    def validate(attr)
      AttributeValidationExpectation.new(attr)
    end

    def succeed
      CommandSucceedExpectation.new
    end
  end
end