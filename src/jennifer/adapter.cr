require "./adapter/base"

module Jennifer
  module Adapter
    @@adapter : Adapter::Mysql? # TODO: make a Adapter::Base

    def self.adapter
      @@adapter ||= adapter_class.not_nil!.new
    end

    def self.adapter_class
      case Config.adapter
      when "mysql"
        Adapter::Mysql
      else
        raise "unspecified adapter type"
      end
    end

    def self.t(value)
      adapter_class.t(value)
    end

    def self.arg_replacement(rhs : Array(Bool | Float32 | Int32 | Jennifer::QueryBuilder::Criteria | String))
      adapter_class.arg_replacement(rhs)
    end

    def self.question_marks(size = 1)
      adapter_class.question_marks(size)
    end
  end
end
