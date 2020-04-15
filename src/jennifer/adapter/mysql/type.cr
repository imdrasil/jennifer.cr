struct MySql::Type
  def self.type_for(t : ::JSON::Any.class)
    MySql::Type::Json
  end

  struct Json < Type
    @@hex_value = 0xF5u8

    def self.db_any_type
      ::String
    end

    def self.write(packet, v : ::JSON::Any)
      packet.write_lenenc_string v.to_json
    end

    def self.read(packet)
      ::JSON.parse(packet.read_lenenc_string)
    end

    def self.parse(str : ::String)
      ::JSON.parse(str)
    end
  end

  Type.types_by_code[0xF5u8] = Json

  # TODO: remove this monkeypatching after merging this PR
  # https://github.com/crystal-lang/crystal-mysql/pull/29
  struct DateTime
    def self.write(packet, v : ::Time)
      packet.write_blob UInt8.slice(
        v.year.to_i16,
        v.year.to_i16/256,
        v.month.to_i8,
        v.day.to_i8,
        v.hour.to_i8,
        v.minute.to_i8,
        v.second.to_i8,
        v.millisecond*1000,
        v.millisecond*1000/256,
        v.millisecond*1000/65536,
        v.millisecond*1000/16777216
      )
    end
  end
end
