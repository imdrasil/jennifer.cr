class Jennifer::QueryBuilder::Criteria
  {% for op in [:overlap, :contain, :contained] %}
    # Presents {{op}} operator.
    #
    # PostgreSQL specific.
    def {{op.id}}(value : Rightable)
      Condition.new(self, {{op}}, value)
    end
  {% end %}
end
