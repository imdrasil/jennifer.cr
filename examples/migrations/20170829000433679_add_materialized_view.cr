class AddMaterializedView20170829000433679 < Jennifer::Migration::Base
  def up
    {% if env("DB") == "postgres" || env("DB") == nil %}
      exec <<-SQL
        CREATE MATERIALIZED VIEW female_contacts
        AS SELECT * FROM contacts WHERE gender = 'female'
      SQL
    {% end %}
  end

  def down
    {% if env("DB") == "postgres" || env("DB") == nil %}
      exec <<-SQL
        DROP MATERIALIZED VIEW female_contacts
      SQL
    {% end %}
  end
end
