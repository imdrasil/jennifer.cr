require "json"

struct MySql::Type
  alias JsonType = ::JSON::Any | ::JSON::Type

  def self.type_for(t : JsonType.class)
    MySql::Type::Json
  end

  decl_type Json, 0xF5u8, ::String do
    def self.write(packet, v : JsonType)
      packet.write_lenenc_string v.to_json
    end

    def self.read(packet)
      ::JSON.parse(packet.read_lenenc_string)
    end

    def self.parse(str : ::String)
      ::JSON.parse(str)
    end
  end

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
