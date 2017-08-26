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
end
