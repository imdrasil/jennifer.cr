Exception::CallStack.skip(__FILE__)

module Jennifer
  # Is raised when pseudo-abstract method is invoked.
  #
  # Pseudo-abstract method - method that can't be marked as abstract but for current level of abstraction
  # it still can't be used.
  class AbstractMethod < Exception
    def initialize(method, klass)
      @message = "Abstract method '#{method}' of '#{klass}' was invoked but it is not implemented yet."
    end
  end

  # Base Jennifer exception.
  class BaseException < Exception
    setter message

    def initialize(base_exception : Exception, extra_message : String? = nil)
      @message =
        if extra_message
          "#{base_exception.message}.\n#{extra_message}"
        else
          base_exception.message
        end
      @cause = base_exception.cause
    end

    def initialize(@message)
    end

    def self.assert_column_count(requested, actual)
      if requested > actual
        raise self.new("ResultSet includes only #{actual} columns when at least #{requested} are required")
      end
    end
  end

  # Wraps driver query native exception with some extra information.
  class BadQuery < BaseException
    def initialize(original_message, query, args)
      @message = "#{original_message}.\nOriginal query was:\n#{BadQuery.format_query(query, args)}"
    end

    def self.prepend_information(error : Exception, query, args)
      error.message = "#{error.message}\nOriginal query was:\n#{format_query(query, args)}"
    end

    def self.format_query(query, args : Array)
      args.empty? ? query : "#{query} | #{args.inspect}"
    end

    def self.format_query(query, arg = nil)
      arg ? "#{query} | #{arg}" : query
    end
  end

  # Presents Jennifer configuration invalidity.
  class InvalidConfig < BaseException
    def initialize(message)
      @message = message
    end

    def self.bad_adapter
      new("No adapter configured")
    end

    def self.bad_database
      new("No database configured")
    end
  end

  # Presents case when record is expected but is not found.
  class RecordNotFound < BaseException
    def initialize(query)
      @message = "There is no record by given query:\n#{query}"
    end

    def self.from_query(query, adapter)
      new(BadQuery.format_query(*adapter.parse_query(adapter.sql_generator.select(query), query.sql_args)))
    end
  end

  class UnknownRelation < BaseException
    def initialize(owner, exception : KeyError)
      initialize(owner, /"(?<r>.*)"$/.match(exception.message.to_s).try &.["r"])
    end

    def initialize(owner, relation)
      @message = "Unknown relation for #{owner}: #{relation}"
    end
  end

  class AlreadyInitialized < BaseException
    def initialize(old_value, new_value)
      @message = "Primary field is already initialized with #{old_value} but #{new_value} was given anyway."
    end
  end

  class RecordInvalid < BaseException
    getter :errors

    def initialize(@errors : Array(String))
      @message = "Object is invalid: #{errors.inspect}"
    end
  end

  # Is used to stop callback invocation.
  class Skip < BaseException
    def initialize
      @message = ""
    end
  end

  class RecordExists < BaseException
    def initialize(record, relation)
      @message = "#{record.class}##{record.primary} has associated records in #{relation} relation"
    end
  end

  class DataTypeMismatch < BaseException
    MATCH_REGS         = [/#read returned a/, /#read the column .* returned a/]
    EXTRACT_WORDS_REGS = [/returned a (.+)\. A (.+) was/, /returned a (.+) but a (.+) was/]

    def initialize(column, klass, exception)
      match = EXTRACT_WORDS_REGS.map(&.match(exception.message.to_s)).compact![0].not_nil!
      @message = "Column #{klass}.#{column} is expected to be a #{match[2]} but got #{match[1]}."
    end

    # TODO: think about monkey patching DB::ResultSet#read for raising custom exception rather than `Exception`
    def self.match?(exception)
      MATCH_REGS.any? { |reg| exception.message =~ reg }
    end

    def self.build(column, klass, exception)
      match?(exception) ? new(column, klass, exception) : exception
    end
  end

  class DataTypeCasting < BaseException
    EXTRACT_WORDS_REG = /[Cc]ast from (.+) to (.+) failed/

    def initialize(column, klass, exception)
      match = EXTRACT_WORDS_REG.match(exception.message.to_s).not_nil!
      @message = "Column #{klass}.#{column} can't be casted from #{match[1]} to it's type - #{match[2]}"
    end

    def self.match?(exception)
      exception.message =~ EXTRACT_WORDS_REG
    end

    def self.build(column, klass, exception)
      match?(exception) ? new(column, klass, exception) : exception
    end
  end

  class UnknownSTIType < BaseException
    def initialize(parent_klass, type)
      @message = "Unknown STI type \"#{type}\" for #{parent_klass}"
    end
  end

  class AmbiguousSQL < BaseException
    def initialize(sql)
      @message = "Ambiguous raw SQL around '%' in '#{sql}'" \
                 " - please pass any string including '%' via query parameters."
    end
  end

  class UnknownAttribute < BaseException
    def initialize(attr, model)
      @message = "Unknown attribute #{attr} for model #{model}"
    end
  end

  class StaleObjectError < BaseException
    def initialize(model)
      @message = "Optimistic locking failed due to stale object for model #{model}"
    end
  end
end
