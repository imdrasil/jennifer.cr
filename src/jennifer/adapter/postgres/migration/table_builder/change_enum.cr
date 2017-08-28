module Jennifer
  module Migration
    module TableBuilder
      class ChangeEnum < Base
        def initialize(name, @options : Hash(Symbol, Array(String)))
          super(name)
          @adapter = Adapter.adapter.as(Adapter::Postgres)
        end

        def process
          remove_values if @options.has_key?(:remove_values)

          add_values if @options.has_key?(:add_values)

          rename_values if @options.has_key?(:rename_values)

          rename(name, @options[:new_name]) if @options.has_key?(:rename)
        end

        def remove_values
          new_values = [] of String
          @adapter.enum_values(@name).each { |e| new_values << e[0] }
          new_values -= @options[:remove_values]
          data_name = @name.dup
          effected_tables =
            Query["information_schema.columns"]
              .select("table_name, column_name")
              .where { (c("udt_name") == data_name) & (c("table_catalog") == Config.db) }
              .pluck(:table_name, :column_name)
          if effected_tables.empty?
            @adapter.drop_enum(@name)
            @adapter.define_enum(@name, new_values)
          else
            temp_name = "#{@name}_temp"
            @adapter.define_enum(temp_name, new_values)
            effected_tables.each do |row|
              @adapter.exec <<-SQL
                ALTER TABLE #{row[0]} 
                ALTER COLUMN #{row[1]} TYPE #{temp_name} 
                USING (#{row[1]}::text::#{temp_name})
              SQL
              @adapter.drop_enum(@name)
              rename(temp_name, @name)
            end
          end
        end

        def add_values
          typed_array_cast(@options[:add_values].as(Array), String).each do |field|
            @adapter.exec "ALTER TYPE #{@name} ADD VALUE '#{field}'"
          end
        end

        def rename_values
          name = @name
          i = 0
          count = @options[:rename_values].as(Array).size
          while i < count
            old_name = @options[:rename_values][i]
            i += 1
            new_name = @options[:rename_values][i]
            i += 1
            Query["pg_enum"].where do
              (c("enumlabel") == old_name) & (c("enumtypid") == sql("SELECT OID FROM pg_type WHERE typname = '#{name}'"))
            end.update({:enumlabel => new_name})
          end
        end

        def rename(old_name, new_name)
          @adapter.exec "ALTER TYPE #{old_name} RENAME TO #{new_name}"
        end
      end
    end
  end
end
