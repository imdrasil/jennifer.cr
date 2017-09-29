class AddMaterializedView20170829000433679 < Jennifer::Migration::Base
  VIEW_NAME = "female_contacts"

  def up
    {% if env("DB") == "postgres" || env("DB") == nil %}
      create_materialized_view(
        VIEW_NAME,
        "SELECT * FROM contacts WHERE gender = 'female'"
      )
    {% end %}
  end

  def down
    {% if env("DB") == "postgres" || env("DB") == nil %}
      drop_materialized_view(VIEW_NAME)
    {% end %}
  end
end
