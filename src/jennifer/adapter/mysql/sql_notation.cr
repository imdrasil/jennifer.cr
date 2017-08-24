module Jennifer
  module Adapter
    module SqlNotation
      def insert(obj : Model::Base)
        opts = obj.arguments_to_insert
        String.build do |s|
          s << "INSERT INTO " << obj.class.table_name
          unless opts[:fields].empty?
            s << "("
            opts[:fields].join(", ", s)
            s << ") VALUES (" << Adapter.adapter_class.escape_string(opts[:fields].size) << ") "
          else
            s << " VALUES ()"
          end
        end
      end
    end
  end
end
