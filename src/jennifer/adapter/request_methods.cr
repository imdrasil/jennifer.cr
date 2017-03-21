alias DB_HASH = Hash(String, DB::Any | Int8 | Int16)

module Jennifer
  module Adapter
    module RequestMethods
      # query ===========================

      def insert(obj : Model::Base)
        opts = self.class.extract_arguments(obj.attributes_hash)
        query = "INSERT INTO #{obj.class.table_name}(#{opts[:fields].join(", ")}) values (#{self.class.escape_string(opts[:fields].size)})"
        exec parse_query(query, opts[:args]), opts[:args]
      rescue e : Exception
        raise BadQuery.new(e.message, body)
      end

      def update(obj : Model::Base)
        opts = self.class.extract_arguments(obj.attributes_hash)
        opts[:args] << obj.primary
        esc = self.class.escape_string(1)
        body = "
        UPDATE #{obj.class.table_name} SET #{opts[:fields].map { |f| f + "= #{esc}" }.join(", ")}
        WHERE #{obj.class.primary_field_name} = #{esc}"
        exec(parse_query(body, opts[:args]), opts[:args])
      end

      def update(q, options : Hash)
        esc = self.class.escape_string(1)
        str = "UPDATE #{q.table} SET #{options.map { |k, v| k.to_s + "= #{esc}" }.join(", ")}\n"
        args = [] of DB::Any
        options.each do |k, v|
          args << v
        end
        str += q.body_section
        args += q.select_args
        exec(parse_query(str, args), args)
      end

      def distinct(query : QueryBuilder::Query, column, table)
        str = String.build do |s|
          s << "SELECT DISTINCT " << table << "." << column << "\n"
          query.from_clause(s)
          s << query.body_section
        end
        args = query.select_args
        result = [] of DB::Any | Int16 | Int8
        query(parse_query(str, args), args) do |rs|
          rs.each do
            result << result_to_array(rs)[0]
          end
        end
        result
      end

      def pluck(query, fields)
        result = [] of DB_HASH
        body = query.select_query(fields)
        args = query.select_args
        query(parse_query(body, args), args) do |rs|
          rs.each do
            result << result_to_hash(rs)
          end
        end
        result
      end

      def select(q)
        body = q.select_query
        args = q.select_args
        query(parse_query(body, args), args) { |rs| yield rs }
      end

      # converts single ResultSet to hash
      def result_to_hash(rs)
        h = {} of String => DB::Any | Int16 | Int8
        rs.column_count.times do |col|
          col_name = rs.column_name(col)
          h[col_name] = rs.read.as(DB::Any | Int16 | Int8)
          if h[col_name].is_a?(Int8)
            h[col_name] = (h[col_name] == 1i8).as(Bool)
          end
        end
        h
      end

      # converts single ResultSet which contains several tables
      def table_row_hash(rs)
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

      def result_to_array(rs)
        a = [] of DB::Any | Int16 | Int8
        rs.columns.each do |col|
          temp = rs.read
          if temp.is_a?(Int8)
            temp = (temp == 1i8).as(Bool)
          end
          a << temp
        end
        a
      end

      # migration ========================
    end
  end
end
