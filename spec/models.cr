class Contact < Jennifer::Model::Base
  with_timestamps
  mapping(
    id: {type: Int32, primary: true},
    name: String,
    age: {type: Int32, default: 10},
    gender: {type: String, default: "male", null: true},
    description: {type: String, null: true},
    created_at: {type: Time, null: true},
    updated_at: {type: Time, null: true}
  )

  has_many :addresses, Address
  has_many :facebook_profiles, FacebookProfile
  has_and_belongs_to_many :countries, Country
  has_and_belongs_to_many :facebook_many_profiles, FacebookProfile, join_foreign: :profile_id
  has_one :main_address, Address, {where { _main }}
  has_one :passport, Passport

  validates_inclucion :age, 13..75
  validates_length :name, minimum: 1, maximum: 15
  validates_with_method :name_check

  scope :main, {where { _age > 18 }}
  scope :older, [age], {where { _age >= age }}
  scope :ordered, {order(name: :asc)}
  scope :with_main_address, {relation(:addresses).where { _addresses__main }}

  def name_check
    if @description && @description.not_nil!.size > 10
      errors.add(:description, "Too large description")
    end
  end
end

class Address < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    main: Bool,
    street: String,
    contact_id: {type: Int32, null: true},
    details: {type: JSON::Any, null: true}
  )
  validates_format :street, /st\.|street/

  belongs_to :contact, Contact

  scope :main, {where { _main }}
end

class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true},
    contact_id: {type: Int32, null: true}
  )

  validates_with [EnnValidator]
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

  has_and_belongs_to_many :facebook_contacts, Contact, foreign: :profile_id
end

class TwitterProfile < Profile
  sti_mapping(
    email: String
  )
end

class Country < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    name: String
  )

  validates_exclusion :name, ["asd", "qwe"]
  validates_uniqueness :name

  has_and_belongs_to_many :contacts, Contact

  {% for callback in [:before_save, :after_save, :after_create, :before_create, :after_initialize, :before_destroy] %}
    getter {{callback.id}}_attr = false

    {{callback.id}} {{callback}}_check

    def {{callback.id}}_check
      @{{callback.id}}_attr = true
    end
  {% end %}
end

class EnnValidator < Accord::Validator
  def initialize(context : Passport)
    @context = context
  end

  def call(errors : Accord::ErrorList)
    if @context.enn!.size < 4 && @context.enn![0].downcase == 'a'
      errors.add(:enn, "Invalid enn")
    end
  end
end
