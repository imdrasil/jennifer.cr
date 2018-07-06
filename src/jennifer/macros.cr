module Jennifer
  # This module contains constants needed only during compilation process to avoid their recreating.
  module Macros
    TYPES                       = %w(Primary32 Primary64)
    NILLABLE_REGEXP             = /(::Nil)|( Nil)/
    JSON_REGEXP                 = /JSON::Any/
    AUTOINCREMENTABLE_STR_TYPES = %w(Int32 Int64)

    Primary32 = {
      type: Int32,
      primary: true
    }

    Primary64 = {
      type: Int64,
      primary: true
    }
  end
end
