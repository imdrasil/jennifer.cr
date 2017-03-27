module Jennifer
  module Support
    def pluralize(str : String)
      str + "s"
    end

    def singularize(str : String)
      str[0...-1]
    end

    macro render_macrosses
      macro typed_hash(hash, key, types)
        begin
          %hash = {} of \{{key.id}} => \{{types.id}}
          \{% for k, v in hash %}
            %hash[\{{k}}] = \{{v}}.as(\{{types.id}})
          \{% end %}
          %hash
        end
      end

      macro as_sym_hash(hash, types)
        begin
          %buf = {} of Symbol => \{{types.id}}
          \{{hash.id}}.each { |k, v| %buf[k] = v.as(\{{types.id}}) }
          %buf
        end
      end

      macro sym_hash(hash, types)
        Support.typed_hash(\{{hash}}, Symbol, \{{types}})
      end

      macro str_hash(hash, types)
        Support.typed_hash(\{{hash}}, String, \{{types}})
      end

      macro arr_cast(arr, klass)
        \{{arr}}.map { |e| e.as(\{{klass}}) }
      end

      macro to_s_hash(hash, types)
        begin
          %hash = {} of String =>\{{types}}
          \{{hash.id}}.each do |k, v|
            %hash[k.to_s] = v
          end
          %hash
        end
      end

      macro singleton_delegate(*methods, to)
        \{% for m in method %}
          def self.\{{m.id}}
            \{{to[:to].id}}.\{{m.id}}
          end
        \{% end %}
      end
    end

    render_macrosses
  end
end

Jennifer::Support.render_macrosses
