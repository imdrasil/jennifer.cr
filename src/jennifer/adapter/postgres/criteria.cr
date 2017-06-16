class Jennifer::QueryBuilder::Criteria
  {% for op in [:overlap, :contain, :contained] %}
    def {{op.id}}(value : Rightable)
      Condition.new(self, {{op}}, value)
    end
  {% end %}
end
