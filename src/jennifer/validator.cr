module Jennifer
  abstract class Validator
    getter errors : Accord::ErrorList

    def initialize(@errors)
    end

    def validate(subject)
      raise raise AbstractMethod.new("validate", self.class)
    end

    def validate(subject, **options)
      raise AbstractMethod.new("validate", self.class)
    end
  end
end
