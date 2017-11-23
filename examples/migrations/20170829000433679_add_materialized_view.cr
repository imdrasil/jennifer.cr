class AddMaterializedView20170829000433679 < Jennifer::Migration::Base
  VIEW_NAME = "female_contacts"

  {% if env("DB") == "postgres" || env("DB") == nil %}
    def up
      create_materialized_view(
        VIEW_NAME,
        Contact.all.where { _gender == sql("'female'") }
      )
    end

    def down
      drop_materialized_view(VIEW_NAME)
    end
  {% else %}
    def up; end

    def down; end
  {% end %}
end
