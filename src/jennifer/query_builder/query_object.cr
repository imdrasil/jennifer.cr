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
    #     article_order = Article.c(params["field"].as(String))
    #     article_order.direction = params["order"].as(String)
    #     article_order
    #   end
    # end
    #
    # class Article < Jennifer::Model::Base
    #   # ...
    #   scope :ordered, OrderedArticlesQuery
    # end
    # ```
    abstract class QueryObject
      getter relation : ::Jennifer::QueryBuilder::IModelQuery, params : Array(Jennifer::DBAny)

      def initialize(@relation)
        @params = [] of Jennifer::DBAny
      end

      # Creates QueryObject based on given *relation* and *options*.
      #
      # NOTE: deprecated - will be removed in 0.7.0.
      def initialize(@relation, *options)
        @params = Ifrit.typed_array_cast(options, Jennifer::DBAny)
      end

      abstract def call
    end
  end
end
