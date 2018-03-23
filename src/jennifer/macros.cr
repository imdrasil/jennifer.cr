alias Primary32 = Int32
alias Primary64 = Int64

module Jennifer
  # This module contains constants needed only during compilation process to avoid their recreating.
  module Macros
    TYPES = [] of String
    NILLABLE_REGEXP             = /(::Nil)|( Nil)/
    JSON_REGEXP                 = /JSON::Any/
    PRIMARY_32                  = "Primary32"
    PRIMARY_64                  = "Primary64"
    AUTOINCREMENTABLE_STR_TYPES = ["Int32", "Int64", "Primary32", "Primary64"]
  end
end
