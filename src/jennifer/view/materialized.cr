module Jennifer
  module View
    # Base class for a database [materialized view](https://en.wikipedia.org/wiki/View_(SQL)#Materialized_views).
    #
    # The only difference from `Base` is one additional method `.refresh` which allows refreshing data of the view.
    # Also this class usage makes sense only if you use PostgreSQL as only it has native support of materialized views.
    abstract class Materialized < Base
      # Refresh materialized view data in th DB.
      def self.refresh
        adapter.refresh_materialized_view(view_name)
      end
    end
  end
end
