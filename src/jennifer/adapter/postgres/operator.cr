struct Jennifer::QueryBuilder::Operator
  def to_sql
    case @type
    when :like
      "LIKE"
    when :not_like
      "NOT LIKE"
    when :regexp
      "~"
    when :not_regexp
      "!~"
    when :==
      "="
    when :is
      "IS"
    when :is_not
      "IS NOT"
    else
      @type.to_s
    end
  end
end
