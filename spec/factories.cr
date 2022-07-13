alias Criteria = Jennifer::QueryBuilder::Criteria
alias Condition = Jennifer::QueryBuilder::Condition
alias Join = Jennifer::QueryBuilder::Join
alias Query = Jennifer::QueryBuilder::Query

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
  argument_type String | Symbol | Criteria | Condition | Query?

  attr :table, "tests"
  attr :on, ->{ Factory.build_criteria == 1 }
  attr :type, :inner
  attr :aliass, nil

  initialize_with do |hash, traits|
    obj = described_class.new(hash["table"].as(String | Query), hash["on"].as(Condition | Criteria), hash["type"].as(Symbol))
    make_assigns(obj, traits)
    obj
  end
end

class ExpressionFactory < Factory::Base
  describe_class Jennifer::QueryBuilder::ExpressionBuilder
  skip_all_constructors

  attr :table, "tests"

  initialize_with do |hash, _traits|
    described_class.new(hash["table"])
  end
end

class QueryFactory < Factory::Base
  describe_class Jennifer::QueryBuilder::Query
  skip_all_constructors

  attr :table, "tests"

  initialize_with do |hash, _traits|
    described_class.new(hash["table"])
  end
end

class UserFactory < Factory::Jennifer::Base
  attr :name, "User"
  sequence(:email) { |i| "email#{i}@example.com" }

  trait :with_valid_password do
    assign :password, "password"
    assign :password_confirmation, "password"
  end

  trait :with_invalid_password_confirmation do
    assign :password, "password"
    assign :password_confirmation, "passwordd"
  end

  trait :with_password_digest do
    attr :password_digest, Crypto::Bcrypt::Password.create("password").to_s, String
  end
end

class ContactFactory < Factory::Jennifer::Base
  postgres_only do
    argument_type(Array(Int32) | Int32 | Int64 | PG::Numeric | String?)
  end

  mysql_only do
    argument_type(Array(Int32) | Int32 | Int64 | Float64 | String?)
  end

  attr :name, "Deepthi"
  attr :age, 28
  attr :description, nil
  attr :email, nil
  attr :gender, "male"
end

class AddressFactory < Factory::Jennifer::Base
  attr :main, false
  sequence(:street) { |i| "Ant st. #{i}" }
  attr :contact_id, nil, Int64?
  attr :details, nil, JSON::Any?
end

class PassportFactory < Factory::Jennifer::Base
  attr :enn, "dsa"
  attr :contact_id, nil, Int64?
end

class CountryFactory < Factory::Jennifer::Base
  attr :name, "Amber"
end

class CityFactory < Factory::Jennifer::Base
  attr :name, "Guda"
  attr :country_id, ->{ Factory.create_country.id }, Int64
  attr :optimistic_lock, 0
end

class ProfileFactory < Factory::Jennifer::Base
  attr :login, "some_login"
  attr :type, Profile.to_s
  attr :contact_id, nil, Int64?
end

class FacebookProfileFactory < ProfileFactory
  describe_class FacebookProfile
  attr :uid, "1234"
  attr :type, FacebookProfile.to_s
end

class TwitterProfileFactory < ProfileFactory
  describe_class TwitterProfile
  attr :email, "some_email@example.com"
  attr :type, TwitterProfile.to_s
end

class MaleContactFactory < Factory::Jennifer::Base
  postgres_only do
    argument_type(Array(Int32) | Int32 | Int64 | PG::Numeric | String? | Time)
  end

  attr :name, "Raphael"
  attr :age, 21
  attr :gender, "male"
  attr :created_at, ->{ Time.utc }
end

class NoteFactory < Factory::Jennifer::Base
  argument_type Jennifer::DBAny

  attr :text, "Some text"
  attr :notable_id, nil
  attr :notable_type, nil

  trait :with_user do
    attr :notable_id, ->{ Factory.create_user([:with_valid_password]).id }, Int64
    attr :notable_type, "User"
  end

  trait :with_contact do
    attr :notable_id, ->{ Factory.create_contact.id }, Int64
    attr :notable_type, "Contact"
  end
end
