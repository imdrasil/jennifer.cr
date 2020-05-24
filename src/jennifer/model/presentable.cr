module Jennifer
  # This is an abstract interface
  module Presentable
    # Returns value by attribute *name* or raises `Jennifer::BaseException` if none.
    #
    # ```
    # User.all.last.attribute(:email) # => "test@example.com"
    # ```
    abstract def attribute(name : String | Symbol, raise_exception : Bool = true)
    # Returns container with object's validation errors.
    abstract def errors : Jennifer::Model::Errors
    # Returns human readable attribute name based on translations.
    abstract def human_attribute_name(name : String | Symbol)
    # Returns field *name* metadata or raises `ArgumentError`.
    abstract def attribute_metadata(name : String | Symbol)
    # Returns underscored model class name.
    #
    # ```
    # Admin::User.all.last.class_name # => "admin_user"
    # ```
    abstract def class_name : String
  end
end
