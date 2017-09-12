alias Criteria = Jennifer::QueryBuilder::Criteria
alias Condition = Jennifer::QueryBuilder::Condition
alias Join = Jennifer::QueryBuilder::Join

class CriteriaFactory < Factory::Base
  describe_class Criteria
  skip_all_constructors

  attr :field, "f1"
  attr :table, "tests"

  initialize_with do |hash, traits|
    obj = described_class.new(field: hash["field"], table: hash["table"])
    make_assigns(obj, traits)
    obj
  end
end

class JoinFactory < Factory::Base
  describe_class Join
  skip_all_constructors
  argument_type String | Symbol | Criteria | Condition

  attr :table, "tests"
  attr :on, ->{ Factory.build_criteria == 1 }
  attr :type, :inner

  initialize_with do |hash, traits|
    obj = described_class.new(hash["table"].as(String), hash["on"].as(Condition | Criteria), hash["type"].as(Symbol))
    make_assigns(obj, traits)
    obj
  end
end

class ExpressionFactory < Factory::Base
  describe_class Jennifer::QueryBuilder::ExpressionBuilder
  skip_all_constructors

  attr :table, "tests"

  initialize_with do |hash, traits|
    described_class.new(hash["table"])
  end
end

class QueryFactory < Factory::Base
  describe_class Jennifer::QueryBuilder::Query
  skip_all_constructors

  attr :table, "tests"

  initialize_with do |hash, traits|
    described_class.new(hash["table"])
  end
end

class ContactFactory < Factory::Jennifer::Base
  postgres_only do
    argument_type (Array(Int32) | Int32 | PG::Numeric | String?)
  end

  attr :name, "Deepthi"
  attr :age, 28
  attr :description, nil
  attr :gender, "male"
end

class AddressFactory < Factory::Jennifer::Base
  attr :main, false
  sequence(:street) { |i| "Ant st. #{i}" }
  attr :contact_id, nil, Int32?
  attr :details, nil, JSON::Any?
end

class PassportFactory < Factory::Jennifer::Base
  attr :enn, "dsa"
  attr :contact_id, nil, Int32?
end

class CountryFactory < Factory::Jennifer::Base
  attr :name, "Amber"
end

class ProfileFactory < Factory::Jennifer::Base
  attr :login, "some_login"
  attr :type, FacebookProfile.to_s
  attr :contact_id, nil, Int32?
end

class FacebookProfileFactory < ProfileFactory
  describe_class FacebookProfile
  attr :uid, "123"
  attr :type, FacebookProfile.to_s
end

class TwitterProfileFactory < ProfileFactory
  describe_class TwitterProfile
  attr :email, "some_email@example.com"
  attr :type, TwitterProfile.to_s
end
