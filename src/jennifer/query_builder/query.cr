require "./*"

module Jennifer
  module QueryBuilder
    class Query(T) < IQuery
      include Enumerable(T)

      def model_class
        T
      end

      def table
        @table.empty? ? T.table_name : @table
      end

      def where(&block)
        ac = Query(T).new(table)
        other = with ac yield
        set_tree(other)
      end

      def join(klass : Class, type = :inner)
        join(klass.table_name, type) { with self yield }
      end

      def join(_table : String, type = :inner)
        ac = Query(T).new(_table)
        other = with ac yield
        @joins << Join.new(_table, other, type)
        self
      end

      def select(raw_sql : String)
        @raw_select = raw_sql
        self
      end

      def left_join(klass : Class, &block)
        join(klass, :left) { with self yield }
      end

      def left_join(_table : String)
        join(_table, :left) { with self yield }
      end

      def right_join(klass : Class)
        join(klass, :right) { with self yield }
      end

      def with(*arr)
        @relations += arr.map(&.to_s).to_a
        self
      end

      def relation(name, type = :inner)
        name = name.to_s
        rel = T.relation(name)
        join(rel.model_class, type) { rel.condition_clause.not_nil! }
        self
      end

      def includes(*names)
        names.each do |name|
          includes(name)
        end
        self
      end

      def includes(name : String | Symbol)
        relation(name).with(name.to_s)
      end

      def having
        ac = Query(T).new(table)
        other = with ac yield
        @having = other
        self
      end

      def destroy
        delete
      end

      def delete
        ::Jennifer::Adapter.adapter.delete(self)
      end

      def exists?
        @limit = 1
        ::Jennifer::Adapter.adapter.exists?(self)
      end

      def count : Int32
        ::Jennifer::Adapter.adapter.count(self)
      end

      def distinct(column, _table)
        ::Jennifer::Adapter.adapter.distinct(self, column, _table)
      end

      def distinct(column : String)
        ::Jennifer::Adapter.adapter.distinct(self, column, table)
      end

      def group(column : String)
        arr = _groups(table)
        arr << column
        self
      end

      def group(*columns)
        _groups(table).concat(columns.to_a)
        self
      end

      def group(**columns)
        columns.each do |t, fields|
          _groups(t.to_s).concat(fields)
        end
        self
      end

      def limit(count)
        @limit = count
        self
      end

      def offset(count)
        @offset = count
        self
      end

      def first
        @limit = 1
        to_a[0]?
      end

      def first!
        @limit = 1
        result = to_a
        raise RecordNotFound.new(self.select_query) if result.empty?
        result[0]
      end

      def pluck(field)
        ::Jennifer::Adapter.adapter.pluck(self, field.to_s)
      end

      def pluck(*fields)
        ::Jennifer::Adapter.adapter.pluck(self, fields.to_a.map(&.to_s))
      end

      # def pluck(**fields)
      #  hash = fields.to_h
      #  result = [] of Hash(String, DB::Any | Int16 | Int8)
      #  ::Jennifer::Adapter.adapter.query(select_query, select_args) do |rs|
      #    rs.each do
      #      h = {} of String => DB::Any | Int8 | Int16
      #      res_hash = ::Jennifer::Adapter.adapter_class.result_to_hash(rs)
      #      fields.each do |k, v|
      #        h[k.to_s] = res_hash[k.to_s]
      #      end
      #      result << h
      #    end
      #  end
      #  result
      # end

      def order(**opts)
        order(opts.to_h)
      end

      def order(opts : Hash(String | Symbol, String | Symbol))
        opts.each do |k, v|
          @order[k.to_s] = v.to_s
        end
        self
      end

      def update(options : Hash)
        ::Jennifer::Adapter.adapter.update(self, options)
      end

      def update(**options)
        update(options.to_h)
      end

      def each
        to_a.each do |e|
          yield e
        end
      end

      def each_result_set(&block)
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            yield rs
          end
        end
      end

      def to_a
        return to_a_with_relations if @relations.size > 0
        result = [] of T
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            result << T.new(rs)
          end
        end
        result
      end

      # ========= private ==============

      private def _groups(name)
        @group[name] ||= [] of String
      end

      private def to_a_with_relations
        h_result = {} of String => T
        nested_hash = @relations.map { |e| {} of String => Bool }
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            h = ::Jennifer::Adapter.adapter.table_row_hash(rs)
            main_field = T.primary_field_name
            next unless h[T.table_name][main_field]?

            obj = (h_result[h[T.table_name][main_field].to_s] ||= T.new(h[T.table_name], false))
            build_relations(h, nested_hash, obj)
          end
        end
        h_result.values
      end

      private def build_relations(parsed_hash, nested_hash, obj : T)
        @relations.each_with_index do |rel_name, i|
          rel = T.relations[rel_name]
          rel_class = rel.model_class
          main_field = rel_class.primary_field_name
          table_name = rel_class.table_name
          next unless parsed_hash[table_name][main_field]
          next if nested_hash[i][parsed_hash[table_name][main_field].to_s]?

          nested_hash[i][parsed_hash[table_name][main_field].to_s] = true
          obj.set_relation(rel_name, parsed_hash[table_name])
        end
      end
    end
  end
end
