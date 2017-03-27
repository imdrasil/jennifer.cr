def criteria_builder(field = "f1", table = "tests")
  Jennifer::QueryBuilder::Criteria.new(field, table)
end

def db_array(*element)
  element.to_a.map { |e| e.as(Jennifer::DBAny) }
end

def join_builder(table = "tests", on = criteria_builder, type = :inner)
  Jennifer::QueryBuilder::Join.new(table, on, type)
end

def operator_builder(type = :==)
  Jennifer::QueryBuilder::Operator.new(type)
end

def query_builder
  Jennifer::QueryBuilder::Query(Contact).new("test")
end

def contact_build(name = "Deepthi", age = 28)
  Contact.new({:name => name, :age => age.to_i16})
end

def address_build(main = false, street = "Ant St.", contact_id = nil, details = nil)
  Address.new({:main => main, :street => street, :contact_id => contact_id, :details => details})
end

def passport_build(enn = "asd", contact_id = nil)
  Passport.new({:enn => enn, :contact_id => contact_id})
end

def contact_create(**params)
  c = contact_build(**params)
  c.save
  c
end

def address_create(**params)
  a = address_build(**params)
  a.save
  a
end

def passport_create(**params)
  p = passport_build(**params)
  p.save
  p
end
