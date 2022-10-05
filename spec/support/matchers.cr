module Spec
  module Methods
    macro match_fields(object, fields)
      {% for field, value in fields %}
        {{object}}.{{field.id}}.should eq({{value}})
      {% end %}
    end

    macro match_fields(object, **fields)
      {% for field, value in fields %}
        {{object}}.{{field.id}}.should eq({{value}})
      {% end %}
    end

    # The following construction
    #
    # ```
    # begin
    #   processor.method_name(argument)
    # rescue e
    #   e.message.should match(/query/)
    #   next
    # end
    # fail "Block wasn't executed"
    # ```
    #
    # uses such `argument` that it makes DB to raise an exception because something doesn't exist (e.g. index name
    # is missing or table). As Jennifer::BadQuery exception includes query this allows testing it until FakeAdapter
    # is not ready.
    macro match_query_from_exception(regex)
      begin
        {{yield}}
        processor.drop_column("table_name", "column")
      rescue e
        e.message.should match({{regex}})
        next
      end
      fail "Block wasn't executed"
    end
  end

  struct MatchArrayExpectation(T)
    def initialize(@array : Array(T))
    end

    def match(given)
      missing = @array - given
      extra = given - @array
      missing.empty? && extra.empty?
    end

    def failure_message(given)
      "Actual array: #{given}; Expected: #{@array}"
    end

    def negative_failure_message(given)
      "Actual array: #{given}; Not expected: #{@array}"
    end
  end

  # :nodoc:
  struct BeValidExpectation
    def match(object)
      object.valid?
    end

    def failure_message(object)
      "Expected: #{object.inspect} to be valid but got errors: #{object.errors.full_messages.inspect}"
    end

    def negative_failure_message(object)
      "Expected: #{object.inspect} not to be valid"
    end
  end

  struct BeInvalidExpectation
    def match(object)
      object.invalid?
    end

    def failure_message(object)
      "Expected: #{object.inspect} to be invalid"
    end

    def negative_failure_message(object)
      "Expected: #{object.inspect} be valid but got errors: #{object.errors.full_messages.inspect}"
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

      object.validate!
      object.errors[@attr].includes?(@error_message)
    end

    def failure_message(object)
      "Expected: #{object.inspect} to have error message: " \
      "'#{@error_message}', but got: '#{object.errors[@attr].inspect}'"
    end

    def negative_failure_message(object)
      "Expected: #{object.inspect} not to have error message: " \
      "'#{@error_message}', but got: '#{object.errors[@attr].inspect}'"
    end
  end

  struct ExecStatusExpectation
    def initialize(@expected_value : Int32)
    end

    def match(tuple)
      tuple[0] == @expected_value
    end

    def failure_message(tuple)
      "Expected command to return status #{@expected_value}, got #{tuple[0]}.\nError message:\n#{tuple[1]}"
    end

    def negative_failure_message(tuple)
      "Expected command to return non #{@expected_value} status, got #{tuple[0]}.\nError message:\n#{tuple[1]}"
    end
  end

  struct MatchCommandExpectation
    def initialize(@command : String, @options : Array(String))
    end

    def match(tuple)
      value = tuple[:output]
      raise "Stub command execution before using expectation" if value.is_a?(IO::Memory)

      output = value.as(Array)
      output[0].as(String) == @command && output[1].as(Array) == @options
    end

    def failure_message(tuple)
      "Expected command to be #{@command} and have options #{@options} but got #{tuple[:output]}"
    end
  end

  struct EqlExpectation(T)
    def initialize(@expected_value : T)
    end

    def match(actual_value)
      actual_value.eql?(@expected_value)
    end

    def failure_message(actual_value)
      expected = @expected_value.inspect
      got = actual_value.inspect
      if expected == got
        expected += " : #{@expected_value.class}"
        got += " : #{actual_value.class}"
      end
      "Expected: #{expected}\n     got: #{got}"
    end

    def negative_failure_message(actual_value)
      "Expected: actual_value != #{@expected_value.inspect}\n     got: #{actual_value.inspect}"
    end
  end

  struct ValidationMessageExpectation
    def initialize(@field : Symbol, @message : String?)
    end

    def match(record)
      errors = (record.errors[@field]? || %w[])
      @message.nil? ? !errors.empty? : errors.includes?(@message)
    end

    def failure_message(record)
      "Expected record to have validation message `#{@message}` for `#{@field}` in `#{record.errors[@field]}`"
    end

    def negative_failure_message(record)
      "Expected record not to have validation message `#{@message}` for `#{@field}` in `#{record.errors[@field]}`"
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

    def eql(value)
      EqlExpectation.new(value)
    end

    def be_valid
      BeValidExpectation.new
    end

    def be_invalid
      BeInvalidExpectation.new
    end

    def validate(attr)
      AttributeValidationExpectation.new(attr)
    end

    def succeed
      status(0)
    end

    def status(value)
      ExecStatusExpectation.new(value)
    end

    def be_executed_as(command, options)
      MatchCommandExpectation.new(command, options)
    end

    def match_array(expected)
      MatchArrayExpectation.new(expected)
    end

    def has_error_message(field : Symbol, message : String? = nil)
      ValidationMessageExpectation.new(field, message)
    end
  end
end
