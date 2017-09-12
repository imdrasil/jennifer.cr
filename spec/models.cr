struct JohnyQuery < Jennifer::QueryBuilder::QueryObject
  def call
    relation.where { _name == "Johny" }
  end
end

struct WithArgumentQuery < Jennifer::QueryBuilder::QueryObject
  def call
    this = self
    relation.where { _age == this.params[0] }
  end
end

class Contact < Jennifer::Model::Base
  with_timestamps
  {% if env("DB") == "postgres" || env("DB") == nil %}
    mapping(
      id:          {type: Int32, primary: true},
      name:        String,
      ballance:    {type: PG::Numeric, null: true},
      age:         {type: Int32, default: 10},
      gender:      {type: String, default: "male", null: true},
      description: {type: String, null: true},
      created_at:  {type: Time, null: true},
      updated_at:  {type: Time, null: true},
      tags: {type: Array(Int32)? },
    )
  {% else %}
    mapping(
      id:          {type: Int32, primary: true},
      name:        String,
      ballance:    {type: Float64, null: true},
      age:         {type: Int32, default: 10},
      gender:      {type: String, default: "male", null: true},
      description: {type: String, null: true},
      created_at:  {type: Time, null: true},
      updated_at:  {type: Time, null: true},
    )
  {% end %}

  has_many :addresses, Address
  has_many :facebook_profiles, FacebookProfile
  has_and_belongs_to_many :countries, Country
  has_and_belongs_to_many :facebook_many_profiles, FacebookProfile, association_foreign: :profile_id
  has_one :main_address, Address, {where { _main }}
  has_one :passport, Passport

  validates_inclucion :age, 13..75
  validates_length :name, minimum: 1, maximum: 15
  validates_with_method :name_check

  scope :main { where { _age > 18 } }
  scope :older { |age| where { _age >= age } }
  scope :ordered { order(name: :asc) }
  scope :with_main_address { relation(:addresses).where { _addresses__main } }
  scope :johny, JohnyQuery
  scope :by_age, WithArgumentQuery

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

  scope :main { where { _main } }

  after_destroy :increment_destroy_counter

  @@destroy_counter = 0

  def self.destroy_counter
    @@destroy_counter
  end

  def increment_destroy_counter
    @@destroy_counter += 1
  end
end

class Passport < Jennifer::Model::Base
  mapping(
    enn: {type: String, primary: true},
    contact_id: {type: Int32, null: true}
  )

  validates_with [EnnValidator]
  belongs_to :contact, Contact

  after_destroy :increment_destroy_counter

  @@destroy_counter = 0

  def self.destroy_counter
    @@destroy_counter
  end

  def increment_destroy_counter
    @@destroy_counter += 1
  end
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

  {% for callback in [:before_save, :after_save, :after_create, :before_create, :after_initialize, :before_destroy, :after_destroy] %}
    getter {{callback.id}}_attr = false

    {{callback.id}} {{callback}}_check

    def {{callback.id}}_check
      @{{callback.id}}_attr = true
    end
  {% end %}

  before_create :test_skip

  def test_skip
    if name == "not create"
      raise ::Jennifer::Skip.new
    end
  end

  def before_destroy_check
    if name == "not kill"
      errors.add(:name, "Cant destroy")
    end
    @before_destroy_attr = true
  end
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

class OneFieldModel < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true}
  )
end

class OneFieldModelWithExtraArgument < Jennifer::Model::Base
  table_name "one_field_models"

  mapping(
    id: {type: Int32, primary: true},
    missing_field: String
  )
end

class ContactWithNotAllFields < Jennifer::Model::Base
  table_name "contacts"

  mapping(
    id: {type: Int32, primary: true},
    name: {type: String, null: true},
  )
end

class ContactWithNotStrictMapping < Jennifer::Model::Base
  table_name "contacts"

  mapping({
    id:   {type: Int32, primary: true},
    name: {type: String, null: true},
  }, false)
end

class ContactWithDependencies < Jennifer::Model::Base
  table_name "contacts"

  mapping({
    id:   {type: Int32, primary: true},
    name: String,
  }, false)

  has_many :addresses, Address, dependent: :delete, foreign: :contact_id
  has_many :facebook_profiles, FacebookProfile, dependent: :nullify, foreign: :contact_id
  has_many :passports, Passport, dependent: :destroy, foreign: :contact_id
  has_many :twitter_profiles, TwitterProfile, dependent: :restrict_with_exception, foreign: :contact_id
end

class ContactWithCustomField < Jennifer::Model::Base
  table_name "contacts"
  mapping({
    id:   {type: Int32, primary: true},
    name: String,
  }, false)
end

class ContactWithNillableName < Jennifer::Model::Base
  table_name "contacts"
  mapping({
    id:   {type: Int32, primary: true},
    name: {type: String, null: true},
  }, false)
end

class FemaleContact < Jennifer::Model::Base
  mapping({
    id:   {type: Int32, primary: true},
    name: {type: String, null: true},
  }, false)
end

# class ContactWithoutId < Jennifer::Model::Base
#   mapping({
#     name: String,
#   })
# end
