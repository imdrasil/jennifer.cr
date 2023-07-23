# Includes all field types except enums and arrays
class AddAllTypeModel < Jennifer::Migration::Base
  def up
    create_table :all_types do |t|
      t.bool :bool_f
      t.bigint :bigint_f
      t.integer :integer_f
      t.short :short_f
      t.float :float_f
      t.double :double_f
      t.decimal :decimal_f
      t.string :string_f
      t.varchar :varchar_f
      t.text :text_f
      t.timestamp :timestamp_f
      t.date_time :date_time_f
      t.date :date_f
      t.json :json_f

      {% if env("DB") == "postgres" || env("DB") == nil %}
        t.oid :oid_f
        t.char :char_f
        t.uuid :uuid_f
        t.timestamptz :timestamptz_f
        t.bytea :bytea_f
        t.jsonb :jsonb_f
        t.xml :xml_f
        t.point :point_f
        t.lseg :lseg_f
        t.path :path_f
        t.box :box_f
        t.integer :array_int32_f, {:array => true}
        t.text :array_string_f, {:array => true}
        t.timestamp :array_time_f, {:array => true}
      {% else %}
        # t.enum
        t.blob :blob_f
        t.tinyint :tinyint_f
      {% end %}
    end
  end

  def down
    drop_table :all_types
  end
end
