module SQLHelpers
  def quote_identifier(definition : String)
    definition.split('.').map! { |e| sql_generator.quote_identifier(e) }.join('.')
  end

  def reg_quote_identifier(definition : String)
    Regex.escape(quote_identifier(definition))
  end

  def sql_generator
    ::Jennifer::Adapter.default_adapter.sql_generator
  end
end

module Spec::Methods
  include SQLHelpers
end
