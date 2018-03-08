module PG
  struct Numeric
    include Comparable(Float64)
    include Comparable(Int32)

    def self.build(*args)
      new(*args)
    end

    def <=>(v : Float64)
      to_f <=> v
    end

    def <=>(v : Int32)
      to_f <=> v
    end
  end
end
