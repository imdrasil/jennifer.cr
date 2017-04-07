class Contact < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    name: String,
    age: {type: Int16, default: 10_i16},
    description: {type: String, null: true}
  )

  has_many :addresses, Address
  has_many :facebook_profiles, FacebookProfile
  has_one :main_address, Address, {where { _main }}
  has_one :passport, Passport

  scope :main, {where { _age > 18 }}
  scope :older, [age], {where { _age >= age }}
  scope :ordered, {order(name: :asc)}
end

class Address < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    main: Bool,
    street: String,
    contact_id: {type: Int32, null: true},
    details: {type: JSON::Any, null: true}
  )

  belongs_to :contact, Contact

  scope :main, {where { _main }}
end

class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true},
    contact_id: {type: Int32, null: true}
  )
  belongs_to :contact, Contact
end

class Profile < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    login: String,
    contact_id: Int32?,
    type: String
  )

  belongs_to :contact, Contact
end

class FacebookProfile < Profile
  sti_mapping(
    uid: String
  )
end

class TwitterProfile < Profile
  sti_mapping(
    email: String
  )
end
