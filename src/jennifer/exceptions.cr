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
end
