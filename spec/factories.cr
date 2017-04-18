def criteria_builder(field = "f1", table = "tests")
  Jennifer::QueryBuilder::Criteria.new(field, table)
end

def db_array(*element)
  element.to_a.map { |e| e.as(Jennifer::DBAny) }
end

def join_builder(table = "tests", on = (criteria_builder == 1), type = :inner)
  Jennifer::QueryBuilder::Join.new(table, on, type)
end

def expression_builder(table = "tests")
  Jennifer::QueryBuilder::ExpressionBuilder.new(table)
end

def query_builder(table = "tests")
  Jennifer::QueryBuilder::PlainQuery.new(table)
end

def contact_build(name = "Deepthi", age = 28, description = nil)
  Contact.build({:name => name, :age => age, :description => description})
end

def address_build(main = false, street = "Ant st.", contact_id = nil, details = nil)
  Address.build({:main => main, :street => street, :contact_id => contact_id, :details => details})
end

def passport_build(enn = "dsa", contact_id = nil)
  Passport.build({:enn => enn, :contact_id => contact_id})
end

def profile_build(login = "some_login", type = FacebookProfile.to_s)
  Profile.build({:login => login, :type => type})
end

def country_build(name = "Amber")
  Country.build({:name => name})
end

def facebook_profile_build(uid = "123", login = "some_login", contact_id = nil)
  FacebookProfile.build({:login => login, :type => FacebookProfile.to_s, :uid => uid, :contact_id => contact_id})
end

def twitter_profile_build(email = "some_eamil@example.com", login = "some_login", contact_id = nil)
  TwitterProfile.build({:login => login, :type => TwitterProfile.to_s, :email => email, :contact_id => contact_id})
end

{% for method in [:facebook_profile, :twitter_profile, :contact, :address, :passport, :country] %}
  def {{method.id}}_create(**params)
    c = {{method.id}}_build(**params)
    c.save
    c
  end
{% end %}
