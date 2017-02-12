module Jennifer
  module Migration
    module TableBuilder
      class CreateTable < Base
        def process
          Adapter.adapter.create_table(self)
        end

        def string(name : String | Symbol, options : Hash(Symbol, EAllowedTypes) | NamedTuple)
          defaults = sym_hash({:type => :string, :size => 254}, AllowedTypes | Symbol)
          @fields[name.to_s] = defaults.merge(options.to_h)
          self
        end

        def integer(name : String | Symbol, options : Hash(Symbol, EAllowedTypes) | NamedTuple)
          defaults = sym_hash({:type => :int}, EAllowedTypes)
          @fields[name.to_s] = defaults.merge(options.to_h)
          self
        end

        def reference(name : String | Symbol)
          @fields[name.to_s + "_id"] = {:type => :int, :null => true}
          self
        end

        def bool(name : String | Symbol, options : Hash(Symbol, EAllowedTypes) | NamedTuple)
          defaults = sym_hash({:type => :bool}, EAllowedTypes)
          @fields[name.to_s] = defaults.merge(options.to_h)
          self
        end

        def string(name : String | Symbol)
          @fields[name.to_s] = sym_hash({:type => :string, :size => 254}, EAllowedTypes)
          self
        end

        def integer(name : String | Symbol)
          @fields[name.to_s] = sym_hash({:type => :int}, EAllowedTypes)
          self
        end

        def bool(name : String | Symbol)
          @fields[name.to_s] = sym_hash({:type => :bool}, EAllowedTypes)
          self
        end

        # TODO: clean up duplications
        # TODO: add text method
      end
    end
  end
end
