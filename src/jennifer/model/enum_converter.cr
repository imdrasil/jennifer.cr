module Jennifer::Model
  # Converts string value to given *T* crystal `enum`.
  #
  # ```
  # enum Category
  #   GOOD
  #   BAD
  # end
  #
  # class Post < Jennifer::Model::Base
  #   mapping(
  #     # ...
  #     category: { type: Category, converter: Jennifer::Model::EnumConverter(Category) }
  #   )
  # end
  # ```
  class EnumConverter(T)
    def self.from_db(pull, nillable)
      value = nillable ? pull.read(String?) : pull.read(String)
      return if value.nil?

      T.parse(value)
    end

    def self.to_db(value : T) : String
      value.to_s
    end

    def self.to_db(value : Nil): Nil
    end

    def self.from_hash(hash : Hash, column)
      value = hash[column]
      case value
      when String
        T.parse(value)
      else
        value
      end
    end
  end
end
