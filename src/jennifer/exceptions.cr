CallStack.skip(__FILE__)

module Jennifer
  class BaseException < Exception
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
  end

  class BadQuery < BaseException
    def initialize(original_message, query)
      @message = "#{original_message}.\nOriginal query was:\n#{query}"
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

  class RecordInvalid < BaseException
    def initialize(obj)
      @message = "Object is invalid: #{obj.to_s}"
    end
  end

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
