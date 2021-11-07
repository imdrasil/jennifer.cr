require "./views"
require "../src/jennifer/model/authentication"

class JohnyQuery < Jennifer::QueryBuilder::QueryObject
  def call
    relation.where { _name == "Johny" }
  end
end

class WithOwnArguments < Jennifer::QueryBuilder::QueryObject
  private getter gender : String

  def initialize(relation, @gender)
    super(relation)
  end

  def call
    relation.where { _gender == gender }
  end
end

class EnnValidator < Jennifer::Validations::Validator
  def validate(record, **opts)
    if record.enn!.size < 4 && record.enn![0].downcase == 'a'
      record.errors.add(:enn, "Invalid enn")
    end
  end
end

class InspectConverter(T)
  def self.from_db(pull, options)
    value = options[:null] ? pull.read(T?) : pull.read(T)
    "#{T}: #{value}" if value
  end

  def self.to_db(value : String, options)
    if T == Int32
      value[("#{T}".size + 2)..-1].to_i
    else
      value[("#{T}".size + 2)..-1]
    end
  end

  def self.to_db(value : Nil, options); end

  def self.from_hash(hash : Hash, column, options)
    value = hash[column]
    "#{T}: #{value}"
  end
end

# ===========
# models
# ===========

abstract class ApplicationRecord < Jennifer::Model::Base
  getter super_class_callback_called = false

  before_create :before_abstract_create

  def before_abstract_create
    @super_class_callback_called = true
  end

  EmptyString = {
    type:    String,
    default: "",
  }

  {% TYPES << "EmptyString" %}
end

class User < ApplicationRecord
  include Jennifer::Model::Authentication

  mapping(
    id: Primary32,
    name: String?,
    password_digest: EmptyString,
    email: {type: EmptyString},
    password: Password,
    password_confirmation: {type: String?, virtual: true}
  )

  with_authentication

  validates_presence :email
  validates_uniqueness :email

  has_many :contacts, Contact, inverse_of: :user

  def self.password_digest_cost
    4
  end
end

class Contact < ApplicationRecord
  module Mapping
    include Jennifer::Model::Mapping

    {% if env("DB") == "postgres" || env("DB") == nil %}
      mapping(
        id: Primary32,
        name: String,
        ballance: PG::Numeric?,
        age: {type: Int32, default: 10},
        gender: {type: String?, default: "male", converter: Jennifer::Model::PgEnumConverter},
        description: String?,
        created_at: Time?,
        updated_at: Time?,
        user_id: Int32?,
        tags: {type: Array(Int32)?},
        email: String?
      )
    {% else %}
      mapping(
        id: Primary32,
        name: String,
        ballance: Float64?,
        age: {type: Int32, default: 10},
        gender: {type: String?, default: "male"},
        description: String?,
        created_at: Time?,
        updated_at: Time?,
        user_id: Int32?,
        email: String?
      )
    {% end %}
  end

  include Mapping

  with_timestamps
  mapping

  has_many :addresses, Address, inverse_of: :contact
  has_many :facebook_profiles, FacebookProfile, inverse_of: :contact
  has_and_belongs_to_many :countries, Country
  has_and_belongs_to_many :facebook_many_profiles, FacebookProfile, association_foreign: :profile_id
  has_one :main_address, Address, {where { _main }}, inverse_of: :contact
  has_one :passport, Passport, inverse_of: :contact
  belongs_to :user, User

  validates_inclusion :age, 13..75
  validates_length :name, minimum: 1
  # NOTE: only for testing purposes - this is a bad practice; prefer to use `in`
  validates_length :name, maximum: 15
  validates_with_method :name_check

  scope :main { where { _age > 18 } }
  scope :older { |age| where { _age >= age } }
  scope :ordered { order(name: :asc) }
  scope :with_main_address { relation(:addresses).where { _addresses__main } }
  scope :johny, JohnyQuery
  scope :by_gender, WithOwnArguments

  def name_check
    if @description && @description.not_nil!.size > 10
      errors.add(:description, "Too large description")
    end
  end
end

class Address < Jennifer::Model::Base
  with_timestamps

  mapping(
    id: {type: Int32, primary: true},
    main: Bool,
    street: String,
    contact_id: Int32?,
    details: JSON::Any?,
    created_at: Time?,
    updated_at: Time?
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
    contact_id: Int32?
  )

  validates_with EnnValidator
  belongs_to :contact, Contact

  validates_uniqueness :enn, :contact_id, allow_blank: true

  after_destroy :increment_destroy_counter

  @@destroy_counter = 0

  def self.destroy_counter
    @@destroy_counter
  end

  def increment_destroy_counter
    @@destroy_counter += 1
  end
end

class Profile < ApplicationRecord
  mapping(
    id: Primary32,
    login: String,
    contact_id: Int32?,
    type: String,
    virtual_parent_field: {type: String?, virtual: true}
  )

  @@destroy_counter = 0

  getter commit_callback_called = false

  belongs_to :contact, Contact

  after_destroy :increment_destroy_counter
  after_commit :set_commit, on: :create

  def self.destroy_counter
    @@destroy_counter
  end

  def increment_destroy_counter
    @@destroy_counter += 1
  end

  def set_commit
    @commit_callback_called = true
  end
end

class FacebookProfile < Profile
  mapping(
    uid: String?, # for testing purposes
    virtual_child_field: {type: Int32?, virtual: true}
  )

  getter fb_commit_callback_called = false

  validates_length :uid, is: 4

  has_and_belongs_to_many :facebook_contacts, Contact, foreign: :profile_id

  after_commit :fb_set_commit, on: :create

  def fb_set_commit
    @fb_commit_callback_called = true
  end
end

class TwitterProfile < Profile
  mapping(
    email: {type: String, null: true} # for testing purposes
  )
end

class Country < Jennifer::Model::Base
  mapping(
    id: Primary32,
    name: String?
  )

  validates_exclusion :name, ["asd", "qwe"]
  validates_uniqueness :name
  validates_presence :name

  has_and_belongs_to_many :contacts, Contact
  has_many :cities, City, inverse_of: :country

  {% for callback in %i(before_save after_save after_create before_create after_initialize
                       before_destroy after_destroy before_update after_update) %}
    getter {{callback.id}}_attr = false

    {{callback.id}} {{callback}}_check

    def {{callback.id}}_check
      @{{callback.id}}_attr = true
    end
  {% end %}

  before_create :test_skip
  before_update :test_skip

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

class City < ApplicationRecord
  with_optimistic_lock :optimistic_lock

  mapping(
    id: Primary32,
    name: String,
    optimistic_lock: {type: Int32, default: 0},
    country_id: Int32
  )

  belongs_to :country, Country
end

class Note < ApplicationRecord
  module Mapping
    macro included
      mapping(
        id: Primary32,
        text: String?,
        notable_id: Int32?,
        notable_type: String?,
        created_at: Time?,
        updated_at: Time?
      )

      with_timestamps
    end
  end

  include Mapping

  belongs_to :notable, Union(User | Contact), {where { _name.like("%on") }}, polymorphic: true
end

class OneFieldModel < Jennifer::Model::Base
  mapping(
    id: Primary64
  )
end

class AllTypeModel < ApplicationRecord
  module SpecificMapping
    include Jennifer::Model::Mapping

    {% if env("DB") == "postgres" || env("DB") == nil %}
      mapping(
        decimal_f: PG::Numeric?,
        oid_f: UInt32?,
        char_f: String?,
        uuid_f: UUID?,
        timestamptz_f: Time?,
        bytea_f: Bytes?,
        jsonb_f: JSON::Any?,
        xml_f: String?,
        point_f: PG::Geo::Point?,
        lseg_f: PG::Geo::LineSegment?,
        path_f: PG::Geo::Path?,
        box_f: PG::Geo::Box?
      )
    {% else %}
      mapping(
        tinyint_f: Int8?,
        decimal_f: Float64?,
        blob_f: Bytes?
      )
    {% end %}
  end

  include SpecificMapping

  table_name "all_types"

  mapping(
    id: Primary32,
    bool_f: Bool?,
    bigint_f: Int64?,
    integer_f: Int32?,
    short_f: Int16?,
    float_f: Float32?,
    double_f: Float64?,
    string_f: String?,
    varchar_f: String?,
    text_f: String?,
    timestamp_f: Time?,
    date_time_f: Time?,
    date_f: Time?,
    json_f: JSON::Any?
  )
end

{% if env("PAIR") == "1" %}
  abstract class PairApplicationRecord < Jennifer::Model::Base
    def self.adapter
      PAIR_ADAPTER
    end
  end

  class PairAddress < PairApplicationRecord
    table_name "addresses"

    mapping(
      id: Primary32,
      street: String?,
      details: JSON::Any?,
      number: Int32?
    )
  end
{% end %}

class Author < Jennifer::Model::Base
  mapping({
    id:        Primary32,
    name1:     {type: String, column: :first_name},
    name2:     {type: String, column: :last_name},
    full_name: {type: String?, generated: true},
  })
end

class Publication < Jennifer::Model::Base
  {% if env("DB") == "postgres" || env("DB") == nil %}
    mapping(
      id: Primary32,
      name: {type: String, column: :title},
      version: Int32,
      publisher: String,
      type: {type: String, converter: Jennifer::Model::PgEnumConverter}
    )
  {% else %}
    mapping(
      id: Primary32,
      name: {type: String, column: :title},
      version: Int32,
      publisher: String,
      type: String
    )
  {% end %}
end

class Book < Publication
  mapping({
    pages: Int32?,
  })
end

class Article < Publication
  mapping({
    size: {type: Int32?, column: :pages},
  })
end

class BlogPost < Publication
  mapping({
    url:        String?,
    created_at: {type: Time?, virtual: true, column: :created},
  })
end

# ===================
# synthetic models
# ===================

class CountryWithTransactionCallbacks < ApplicationRecord
  table_name "countries"

  mapping({
    id:   Primary32,
    name: String,
  }, false)

  {% for action in [:create, :save, :destroy, :update] %}
    {% for type in [:commit, :rollback] %}
      {% name = "#{action.id}_#{type.id}_callback".id %}

      after_{{type.id}} :set_{{name}}, on: {{action}}

      getter {{name}} = false

      def set_{{name}}
        @{{name}} = true
      end
    {% end %}
  {% end %}
end

class CountryWithValidationCallbacks < ApplicationRecord
  table_name "countries"

  mapping({
    id:   Primary32,
    name: String,
  })

  before_validation :raise_skip, :before_validation_method
  after_validation :after_validation_method

  validates_with_method :validate_downcase

  private def validate_downcase
    errors.add(:name, "can't be downcased") if name =~ /[A-Z]/
  end

  private def before_validation_method
    if name == "UPCASED"
      self.name = name.downcase
    end
  end

  private def after_validation_method
    if name == "downcased"
      self.name = name.upcase
    end
  end

  private def raise_skip
    raise Jennifer::Skip.new if name == "skip"
  end
end

class JohnPassport < Jennifer::Model::Base
  table_name "passports"

  mapping(
    enn: {type: String, primary: true},
    contact_id: Int32?
  )

  belongs_to :contact, Contact, {where { _name == "John" }}
end

class OneFieldModelWithExtraArgument < Jennifer::Model::Base
  table_name "one_field_models"

  mapping(
    id: Primary64,
    missing_field: String
  )
end

class ContactWithNotAllFields < Jennifer::Model::Base
  table_name "contacts"

  mapping(
    id: Primary32,
    name: String?,
  )
end

class ContactWithNotStrictMapping < Jennifer::Model::Base
  table_name "contacts"

  mapping({
    id:   Primary32,
    name: String?,
  }, false)
end

class ContactWithDependencies < Jennifer::Model::Base
  table_name "contacts"

  {% if env("DB") == "postgres" || env("DB") == nil %}
    mapping({
      id:          Primary32,
      name:        String?,
      description: String?,
      age:         {type: Int32, default: 10},
      gender:      {type: String?, default: "male", converter: Jennifer::Model::PgEnumConverter},
    }, false)
  {% else %}
    mapping({
      id:          Primary32,
      name:        String?,
      description: String?,
      age:         {type: Int32, default: 10},
      gender:      {type: String?, default: "male"},
    }, false)
  {% end %}

  has_many :addresses, Address, dependent: :delete, foreign: :contact_id
  has_many :facebook_profiles, FacebookProfile, dependent: :nullify, foreign: :contact_id
  has_many :passports, Passport, dependent: :destroy, foreign: :contact_id
  has_many :twitter_profiles, TwitterProfile, dependent: :restrict_with_exception, foreign: :contact_id
  has_and_belongs_to_many :u_countries, Country, {where { _name.like("U%") }}, foreign: :contact_id

  validates_length :name, minimum: 2
  validates_length :description, minimum: 2, allow_blank: true
end

class ContactWithCustomField < Jennifer::Model::Base
  table_name "contacts"
  mapping({
    id:   Primary32,
    name: String,
  }, false)
end

class ContactWithInValidation < Jennifer::Model::Base
  table_name "contacts"
  mapping({
    id:   Primary64,
    name: String?,
  }, false)

  validates_length :name, in: 2..10
end

class ContactWithNillableName < Jennifer::Model::Base
  table_name "contacts"
  mapping({
    id:   Primary32,
    name: String?,
  }, false)
end

class AbstractContactModel < Jennifer::Model::Base
  table_name "contacts"
  mapping({
    id:   Primary32,
    name: String?,
    age:  Int32,
  }, false)
end

{% if env("DB") == "postgres" || env("DB") == nil %}
  class ContactWithFloatMapping < Jennifer::Model::Base
    table_name "contacts"

    mapping({
      id:       Primary32,
      ballance: {type: Float64?, converter: Jennifer::Model::NumericToFloat64Converter},
    }, false)
  end
{% end %}

class CountryWithDefault < Jennifer::Model::Base
  mapping(
    id: Primary32,
    virtual: {type: Bool, default: true, virtual: true},
    name: String?
  )
end

class NoteWithCallback < ApplicationRecord
  include Note::Mapping

  self.table_name "notes"

  belongs_to :notable, Union(User | FacebookProfileWithDestroyNotable), polymorphic: true

  after_destroy :increment_destroy_counter

  @@destroy_counter = 0

  def self.destroy_counter
    @@destroy_counter
  end

  def increment_destroy_counter
    @@destroy_counter += 1
  end
end

class FacebookProfileWithDestroyNotable < Jennifer::Model::Base
  module Mapping
    macro included
      mapping({
        id: Primary32,
        login: String,
        contact_id: Int32?,
        type: String,
        uid: String?
    }, false)
    end
  end

  include Mapping

  table_name "profiles"

  has_many :notes, NoteWithCallback, inverse_of: :notable, polymorphic: true, dependent: :destroy

  after_destroy :increment_destroy_counter

  @@destroy_counter = 0

  def self.destroy_counter
    @@destroy_counter
  end

  def increment_destroy_counter
    @@destroy_counter += 1
  end
end

class ProfileWithOneNote < Jennifer::Model::Base
  include FacebookProfileWithDestroyNotable::Mapping

  table_name "profiles"

  has_one :note, NoteWithCallback, inverse_of: :notable, polymorphic: true, dependent: :nullify
end

class AddressWithNilableBool < Jennifer::Model::Base
  with_timestamps

  mapping({
    id:   {type: Int32, primary: true},
    main: Bool?,
  }, false)
end

class NoteWithManualId < Jennifer::Model::Base
  table_name "notes"
  with_timestamps

  mapping(
    id: {type: Primary32, auto: false},
    text: {type: String?},
    created_at: Time?,
    updated_at: Time?
  )
end

class OrderItem < ApplicationRecord
  table_name "all_types"

  mapping(id: Primary32)
end

class PolymorphicNote < ApplicationRecord
  include ::Note::Mapping

  table_name "notes"

  belongs_to :notable, Union(::User | ContactForPolymorphicNote), polymorphic: true

  def self.table_prefix; end
end

class PolymorphicNoteWithConverter < Jennifer::Model::Base
  table_name "notes"

  mapping(
    id: Primary32,
    notable_id: {type: String, converter: InspectConverter(Int32)},
    notable_type: {type: String, converter: InspectConverter(String)}
  )

  belongs_to :notable, Union(::User | ContactForPolymorphicNote), polymorphic: true
end

class ContactForPolymorphicNote < ApplicationRecord
  include ::Contact::Mapping

  table_name "contacts"

  mapping

  has_many :notes, PolymorphicNote, inverse_of: :notable, polymorphic: true
  has_one :note_converter, PolymorphicNoteWithConverter, inverse_of: :notable, polymorphic: true
end
