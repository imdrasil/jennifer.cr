class Contact < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    name: String,
    age: {type: Int32, default: 10}
  )

  has_many :addresses, Address
  has_one :passport, Passport
end

class Address < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    main: Bool,
    street: String,
    contact_id: {type: Int32, null: true}
  )

  table_name "addresses"
  belongs_to :contact, Contact
end

class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true},
    contact_id: {type: Int32, null: true}
  )
  belongs_to :contact, Contact
end
