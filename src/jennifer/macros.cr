module Jennifer
  # This module contains constants needed only during compilation process to avoid their recreating.
  module Macros
    # :nodoc:
    TYPES = %w(Primary32 Primary64)
    # :nodoc:
    AUTOINCREMENTABLE_STR_TYPES = %w(Int32 Int64)

    # Mapping type for `Int32` primary key.
    Primary32 = {
      type:    Int32?,
      primary: true,
      auto:    true,
    }

    # Mapping type for `Int64` primary key.
    Primary64 = {
      type:    Int64?,
      primary: true,
      auto:    true,
    }
  end
end
