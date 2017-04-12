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

      def exec(&block)
        with self yield
        self
      end

      def where(&block)
        other = with @expression yield
        set_tree(other)
      end

      def select(raw_sql : String)
        @raw_select = raw_sql
        self
      end

      def join(klass : Class, aliass : String? = nil, type = :inner, relation : String? = nil)
        eb = ExpressionBuilder.new(klass.table_name, relation, self)
        with_relation! if relation
        other = with eb yield eb
        @joins << Join.new(klass.table_name, other, type, relation: relation)
        self
      end

      def join(_table : String, aliass : String? = nil, type = :inner, relation : String? = nil)
        eb = ExpressionBuilder.new(_table, relation, self)
        with_relation! if relation
        other = with eb yield eb
        @joins << Join.new(_table, other, type, relation)
        self
      end

      def left_join(klass : Class, aliass : String? = nil)
        join(klass, aliass, :left) { |eb| with eb yield }
      end

      def left_join(_table : String, aliass : String? = nil)
        join(_table, aliass, :left) { |eb| with eb yield }
      end

      def right_join(klass : Class, aliass : String? = nil)
        join(klass, aliass, :right) { |eb| with eb yield }
      end

      def right_join(_table : String)
        join(_table, aliass, :left) { |eb| with eb yield }
      end

      def with(*arr)
        arr.map(&.to_s).to_a.each do |name|
          table_name = T.relation(name).table_name
          temp_joins = @joins.select { |j| j.table == table_name }
          join = temp_joins.find(&.relation.nil?)
          if join
            join.not_nil!.relation = name
          elsif temp_joins.size == 0
            raise BaseException.new("#with should be called after correspond join: no such table \"#{table_name}\" of relation \"#{name}\"")
          end
          @relations << name
        end
        self
      end

      def relation(name, type = :inner)
        T.relation(name.to_s).join_condition(self, type)
      end

      def includes(*names)
        names.each do |name|
          includes(name)
        end
        self
      end

      def includes(name : String | Symbol)
        @relations << name.to_s
        relation(name)
      end

      def includes(rels : Array(String), aliases = [] of String?)
        @relations << name.to_s
        raise "Not implemented"
      end

      def having
        other = with @expression yield
        @having = other
        self
      end

      def destroy
        to_a.each(&.destroy)
      end

      def delete
        ::Jennifer::Adapter.adapter.delete(self)
      end

      def exists?
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

      def last
        reverse_order
        old_limit = @limit
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        reverse_order
        r
      end

      def last!
        old_limit = @limit
        @limit = 1
        reverse_order
        result = to_a
        reverse_order
        @limit = old_limit
        raise RecordNotFound.new(self.select_query) if result.empty?
        result[0]
      end

      def first
        old_limit = @limit
        @limit = 1
        r = to_a[0]?
        @limit = old_limit
        r
      end

      def first!
        old_limit = @limit
        @limit = 1
        result = to_a
        @limit = old_limit
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

      def find_batch(batch_size = 1000)
        raise "Not implemented"
      end

      def each_result_set(&block)
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            yield rs
          end
        end
      end

      def to_a
        add_aliases if @relation_used
        return to_a_with_relations if @relations.size > 0
        result = [] of T
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            result << T.build(rs)
          end
        end
        result
      end

      # works only if there is id field and it is covertable to Int32
      def ids
        pluck(:id).map(&.to_i)
      end

      # ========= private ==============

      private def reverse_order
        if @order.empty?
          @order[T.primary_field_name] = "DESC"
        else
          @order.each do |k, v|
            @order[k] =
              case v
              when "asc", "ASC"
                "DESC"
              else
                "ASC"
              end
          end
        end
      end

      private def _groups(name)
        @group[name] ||= [] of String
      end

      private def to_a_with_relations
        h_result = {} of String => T

        models = @relations.map { |e| T.relations[e].model_class }
        existence = @relations.map { |_| {} of String => Bool }
        ::Jennifer::Adapter.adapter.select(self) do |rs|
          rs.each do
            h = build_hash(rs, T.field_count)
            main_field = T.primary_field_name
            if h[main_field]?
              obj = (h_result[h[main_field].to_s] ||= T.build(h, false))
              models.each_with_index do |model, i|
                h = build_hash(rs, model.field_count)
                pfn = model.primary_field_name
                if h[pfn].nil? || existence[i][h[pfn].to_s]?
                  (rs.column_count - rs.column_index).times do |i|
                    rs.read
                  end
                  break
                else
                  existence[i][h[pfn].to_s] = true
                  obj.append_relation(@relations[i], h)
                end
              end
            else
              (rs.column_count - T.field_count).times { |_| rs.read }
            end
          end
        end
        h_result.values
      end

      private def add_aliases
        table_names = [table] + @joins.map { |e| e.table if !e.aliass }.compact
        duplicates = extract_duplicates(table_names)
        return if duplicates.empty?
        i = 0
        @table_aliases.clear
        @joins.each do |j|
          if j.relation && duplicates.includes?(j.table)
            @table_aliases[j.relation.as(String)] = "t#{i}"
            i += 1
          end
        end
        @joins.each { |j| j.alias_tables(@table_aliases) }
        @tree.not_nil!.alias_tables(@table_aliases) if @tree
      end

      private def build_hash(rs, size)
        h = {} of String => DBAny
        size.times do |i|
          h[rs.current_column_name] = rs.read
        end
        h
      end

      private def extract_duplicates(arr)
        result = [] of String
        entries = Hash(String, Int32).new(0)

        arr.each do |name|
          entries[name] += 1
        end
        result = [] of String
        entries.each { |k, v| result << k if v > 1 }
        result
      end
    end
  end
end
