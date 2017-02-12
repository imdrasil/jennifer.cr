require "../src/prequel"
require "./migrations/*"

class Contact < Prequel::BaseModel
  mapping(
    id: {type: Int64, primary: true},
    name: String,
    age: {type: Int32, default: 10}
  )
end

class Address < Prequel::BaseModel
  mapping(
    id: Int64,
    main: Bool,
    street: String
  )

  table_name "addresses"
end

Prequel::Config.configure do |conf|
  conf.host = "localhost"
  conf.user = "root"
  conf.password = ""
  conf.adapter = "mysql"
  conf.db = "prequel_test"
end

Prequel::Migration::Runner.drop
Prequel::Migration::Runner.create
Prequel::Migration::Runner.migrate

t = Time.now
1000.times do
  Contact.create(name: "John Doe", age: 30)
end
puts Time.now - t
