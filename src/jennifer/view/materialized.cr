module Jennifer
  module View
    abstract class Materialized < Base
      def self.refresh
        adapter.refresh_materialized_view(view_name)
      end
    end
  end
end
