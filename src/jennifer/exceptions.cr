CallStack.skip(__FILE__)

module Jennifer
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

  class InvalidConfig < BaseException
    def initialize(message)
      @message = message
    end
  end

  class RecordNotFound < BaseException
    def initialize(query)
      @message = "There is no record by given query:\n#{query}"
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

    def initialize(@errors : Accord::ErrorList)
      @message = "Object is invalid: #{errors.inspect}"
    end
  end

  # Exception class to stoping model callback invoking.
  class Skip < BaseException
    def initialize
      @message = ""
    end
  end

  class UnknownAdapter < BaseException
    def initialize(name, available)
      @message = "Unknown adapter #{name}, available adapters are #{available.join(", ")}"
    end
  end

  class RecordExists < BaseException
    def initialize(record, relation)
      @message = "#{record.class}##{record.primary} has associated records in #{relation} relation"
    end
  end

  class DataTypeMismatch < BaseException
    MATCH_REG         = /#read returned a/
    EXTRACT_WORDS_REG = /returned a (.+)\. A (.+) was/

    def initialize(column, klass, exception)
      match = EXTRACT_WORDS_REG.match(exception.message.to_s).not_nil!
      @message = "Column #{klass}.#{column} is expected to be a #{match[2]} but got #{match[1]}."
    end

    # TODO: think about monkey patching DB::ResultSet#read for raising custome execption raather than `Exception`
    def self.match?(exception)
      exception.message =~ MATCH_REG
    end
  end

  class DataTypeCasting < BaseException
    EXTRACT_WORDS_REG = /cast from (.+) to (.+) failed/

    def initialize(column, klass, exception)
      match = EXTRACT_WORDS_REG.match(exception.message.to_s).not_nil!
      @message = "Column #{klass}.#{column} can't be casted from #{match[1]} to it's type - #{match[2]}"
    end

    def self.match?(exception)
      exception.message =~ EXTRACT_WORDS_REG
    end
  end
end
