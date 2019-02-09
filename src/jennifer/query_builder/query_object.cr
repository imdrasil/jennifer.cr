module Jennifer
  module QueryBuilder
    # Base abstract class for query object.
    #
    # ```
    # class OrderedArticlesQuery < Jennifer::QueryBuilder::QueryObject
    #   SORTABLE_FIELDS = %w(by_date by_title by_author)
    #
    #   private getter field : Sting, order : String
    #
    #   def initialize(relation, field, order)
    #     super(relation)
    #     @order = order == "asc" ? order : "desc"
    #     @field = SORTABLE_FIELDS.includes?(field) ? field : "by_date"
    #   end
    #
    #   def call
    #     relation.order { article_order }
    #   end
    #
    #   private def article_order
    #     Article.c(field).tap { |article_order| article_order.direction = order }
    #   end
    # end
    #
    # class Article < Jennifer::Model::Base
    #   # ...
    #   scope :ordered, OrderedArticlesQuery
    # end
    #
    # Article.all.ordered("by_date", "desc")
    # ```
    abstract class QueryObject
      getter relation : ::Jennifer::QueryBuilder::IModelQuery

      def initialize(@relation)
      end

      abstract def call
    end
  end
end
