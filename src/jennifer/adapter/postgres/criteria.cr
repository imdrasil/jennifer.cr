class Jennifer::QueryBuilder::Criteria
  {% for op in [:overlap, :contain, :contained] %}
    def {{op.id}}(value : Rightable)
      Condition.new(self, {{op}}, value)
    end
  {% end %}

  def similar(value : String)
    Condition.new(self, :similar, value)
  end
end
