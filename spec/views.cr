abstract class BaseView < Jennifer::View::Materialized
  BlankString = {
    type: String,
    null: true
  }

  {% Jennifer::Macros::TYPES << "BlankString" %}
end

class FemaleContact < BaseView
  mapping({
    id:   Primary32,
    name: BlankString,
  }, false)
end

class MaleContact < Jennifer::View::Base
  mapping({
    id:         Primary32,
    name:       String,
    gender:     String,
    age:        Int32,
    created_at: Time?,
  }, false)

  scope :main { where { _age < 50 } }
  scope :older { |age| where { _age >= age } }
  scope :johny, JohnyQuery
end

# ==================
# synthetic views
# ==================

class FakeFemaleContact < Jennifer::View::Base
  view_name "female_contacs"

  mapping({
    id:         Primary32,
    name:       String,
    gender:     String,
    age:        Int32,
    created_at: Time?,
  }, false)
end

class FakeContactView < Jennifer::View::Base
  view_name "male_contacs"

  mapping({
    id: Primary32,
  }, false)
end

class StrinctBrokenMaleContact < Jennifer::View::Base
  view_name "male_contacts"
  mapping({
    id:   Primary32,
    name: String,
  })
end

class StrictMaleContactWithExtraField < Jennifer::View::Base
  view_name "male_contacts"
  mapping({
    id:            Primary64,
    missing_field: String,
  })
end

class MaleContactWithDescription < Jennifer::View::Base
  view_name "male_contacts"
  mapping({
    id:          Primary32,
    description: String,
  }, false)
end
