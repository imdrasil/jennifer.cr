require "db"

class DB::ResultSet
  getter column_index

  @column_index = 0

  def current_column
    @columns[@column_index]
  end

  def current_column_name
    column_name(@column_index)
  end
end

module Jennifer
  module Adapter
    abstract class Base
      @connection : DB::Database

      getter connection

      delegate exec, query, scalar, to: @connection

      def initialize
        @connection = DB.open(Base.connection_string(:db))
      end

      def self.db_connection
        DB.open(connection_string) do |db|
          yield(db)
        end
      end

      def self.connection_string(*options)
        auth_part = Config.user
        auth_part += ":#{Config.password}" if Config.password && !Config.password.empty?
        str = "#{Config.adapter}://#{auth_part}@#{Config.host}"
        str += "/" + Config.db if options.includes?(:db)
        str
      end

      def self.extract_arguments(hash)
        args = [] of DB::Any
        fields = [] of String
        hash.each do |key, value|
          fields << key.to_s
          args << value
        end
        {args: args, fields: fields}
      end

      def self.result_to_hash(rs)
        h = {} of String => DB::Any | Int16 | Int8
        rs.columns.each do |col|
          h[col.name] = rs.read
          if h[col.name].is_a?(Int8)
            h[col.name] = (h[col.name] == 1i8).as(Bool)
          end
        end
        h
      end

      def self.table_row_hash(rs)
        h = {} of String => Hash(String, DB::Any | Int16 | Int8)
        rs.columns.each do |col|
          h[col.table] ||= {} of String => DB::Any | Int16 | Int8
          h[col.table][col.name] = rs.read
          if h[col.table][col.name].is_a?(Int8)
            h[col.table][col.name] = h[col.table][col.name] == 1i8
          end
        end
        h
      end

      def self.arg_replacement(arr)
        question_marks(arr.size)
      end

      def self.question_marks(size = 1)
        case size
        when 1
          "?"
        when 2
          "?, ?"
        when 3
          "?, ?, ?"
        else
          size.times.map { "?" }.join(", ")
        end
      end
    end
  end
end
