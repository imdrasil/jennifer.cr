class Contact < ApplicationRecord
  module Mapping
    include Jennifer::Model::Mapping

    {% if env("DB") == "postgres" || env("DB") == nil %}
      mapping(
        id: Primary64,
        name: String,
        ballance: PG::Numeric?,
        age: {type: Int32, default: 10},
        gender: {type: String?, default: "male", converter: Jennifer::Model::PgEnumConverter},
        description: String?,
        created_at: Time?,
        updated_at: Time?,
        user_id: Int64?,
        tags: {type: Array(Int32)?},
        email: String?
      )
    {% else %}
      mapping(
        id: Primary64,
        name: String,
        ballance: Float64?,
        age: {type: Int32, default: 10},
        gender: {type: String?, default: "male"},
        description: String?,
        created_at: Time?,
        updated_at: Time?,
        user_id: Int64?,
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
