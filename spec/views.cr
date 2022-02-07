abstract class BaseView < Jennifer::View::Materialized
  BlankString = {
    type: String,
    null: true,
  }

  {% Jennifer::Macros::TYPES << "BlankString" %}
end

class FemaleContact < BaseView
  mapping({
    id:   Primary64,
    name: BlankString,
  }, false)
end

class MaleContact < Jennifer::View::Base
  {% if env("DB") == "postgres" || env("DB") == nil %}
    mapping({
      id:         Primary64,
      name:       String,
      gender:     {type: String, converter: Jennifer::Model::PgEnumConverter},
      age:        Int32,
      created_at: Time?,
    }, false)
  {% else %}
    mapping({
      id:         Primary64,
      name:       String,
      gender:     String,
      age:        Int32,
      created_at: Time?,
    }, false)
  {% end %}

  scope :main { where { _age < 50 } }
  scope :older { |age| where { _age >= age } }
  scope :johny, JohnyQuery
end

# ==================
# synthetic views
# ==================

class FakeFemaleContact < Jennifer::View::Base
  view_name "female_contacts"

  {% if env("DB") == "postgres" || env("DB") == nil %}
    mapping({
      id:         Primary64,
      name:       String,
      gender:     {type: String, converter: Jennifer::Model::PgEnumConverter},
      age:        Int32,
      created_at: Time?,
    }, false)
  {% else %}
    mapping({
      id:         Primary64,
      name:       String,
      gender:     String,
      age:        Int32,
      created_at: Time?,
    }, false)
  {% end %}
end

class FakeContactView < Jennifer::View::Base
  view_name "male_contacs"

  mapping({
    id: Primary64,
  }, false)
end

class StrictBrokenMaleContact < Jennifer::View::Base
  view_name "male_contacts"

  mapping({
    id:   Primary64,
    name: String,
  })
end

class StrictMaleContactWithExtraField < Jennifer::View::Base
  view_name "male_contacts"
  mapping({
    id:            Primary32,
    missing_field: String,
  })
end

class MaleContactWithDescription < Jennifer::View::Base
  view_name "male_contacts"
  mapping({
    id:          Primary64,
    description: String,
  }, false)
end

class PrintPublication < Jennifer::View::Base
  {% if env("DB") == "postgres" || env("DB") == nil %}
    mapping(
      id: Primary64,
      title: String,
      v: {type: Int32, column: :version},
      publisher: String,
      pages: Int32?,
      url: String?,
      type: {type: String, converter: Jennifer::Model::PgEnumConverter}
    )
  {% else %}
    mapping(
      id: Primary64,
      title: String,
      v: {type: Int32, column: :version},
      publisher: String,
      pages: Int32?,
      url: String?,
      type: String
    )
  {% end %}
end
