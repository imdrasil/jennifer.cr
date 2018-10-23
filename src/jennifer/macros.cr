module Jennifer
  # This module contains constants needed only during compilation process to avoid their recreating.
  module Macros
    # :nodoc:
    TYPES                       = %w(Primary32 Primary64)
    # :nodoc:
    NILLABLE_REGEXP             = /(::Nil)|( Nil)/
    # :nodoc:
    JSON_REGEXP                 = /JSON::Any/
    # :nodoc:
    AUTOINCREMENTABLE_STR_TYPES = %w(Int32 Int64)

    # Primary key type (Int32).
    Primary32 = {
      type: Int32,
      primary: true
    }

    # Primary key type (Int64).
    Primary64 = {
      type: Int64,
      primary: true
    }
  end
end
