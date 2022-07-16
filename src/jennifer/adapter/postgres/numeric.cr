# :nodoc:
module PG
  struct Numeric
    include Comparable(Float64)
    include Comparable(Int32)

    def self.build(*args)
      new(*args)
    end

    def <=>(other : Float64)
      to_f <=> other
    end

    def <=>(other : Int32)
      to_f <=> other
    end
  end
end
