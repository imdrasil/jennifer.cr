module Jennifer
  # Base class for custom validator.
  abstract class Validator
    getter errors : Model::Errors

    def initialize(@errors)
    end

    def validate(subject)
      raise AbstractMethod.new("validate", self.class)
    end

    def validate(subject, **options)
      raise AbstractMethod.new("validate", self.class)
    end
  end
end
