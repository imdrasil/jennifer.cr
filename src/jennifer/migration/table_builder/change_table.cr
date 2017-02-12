module Jennifer
  module Migration
    module TableBuilder
      class ChangeTable < Base
        def rename_table(new_name)
          @fields[:rename] = {:name => new_name}
        end

        def change_column(old_name, new_name, type, options = {} of String => String)
          # @fields[:change_column] ||= [] of Hash
        end

        def process
          Adapter.adapter.change_table(self)
        end
      end
    end
  end
end
