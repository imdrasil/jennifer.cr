class Jennifer::QueryBuilder::Condition
  def operator_to_sql
    case @operator
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
      @operator.to_s
    end
  end
end
