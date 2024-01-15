module Jennifer
  module Postgres
    module Migration
      module TableBuilder
        class ChangeEnum < Base
          @effected_tables : Array(Array(DBAny))

          def initialize(adapter, name, @options : Hash(Symbol, Array(String)))
            super(adapter, name)
            @effected_tables = _effected_tables
          end

          def process
            remove_values if @options.has_key?(:remove_values)
            add_values if @options.has_key?(:add_values)
            rename_values if @options.has_key?(:rename_values)
            rename(name, @options[:new_name]) if @options.has_key?(:rename)
          end

          def explain
            "change_enum :#{@name}, #{@options.inspect}"
          end

          def remove_values
            new_values = adapter.enum_values(@name)
            new_values -= @options[:remove_values]
            if @effected_tables.empty?
              schema_processor.drop_enum(@name)
              schema_processor.define_enum(@name, new_values)
            else
              temp_name = "#{@name}_temp"
              schema_processor.define_enum(temp_name, new_values)
              @effected_tables.each do |row|
                query = String.build do |io|
                  io << "ALTER TABLE " << row[0]
                  io << " ALTER COLUMN " << row[1] << " TYPE " << temp_name
                  io << " USING (" << row[1] << "::text::" << temp_name << ")"
                end
                @adapter.exec query

                schema_processor.drop_enum(@name)
                rename(temp_name, @name)
              end
            end
          end

          def add_values
            Ifrit.typed_array_cast(@options[:add_values].as(Array), String).each do |field|
              adapter.exec "ALTER TYPE #{@name} ADD VALUE '#{field}'"
            end
          end

          def rename_values
            name = @name
            i = 0
            count = @options[:rename_values].as(Array).size
            while i < count
              old_name = @options[:rename_values][i]
              new_name = @options[:rename_values][i + 1]
              i += 2
              Query["pg_enum"].where do
                (c("enumlabel") == old_name) & (c("enumtypid") == sql("SELECT OID FROM pg_type WHERE typname = '#{name}'"))
              end.update({:enumlabel => new_name})
            end
          end

          def rename(old_name, new_name)
            adapter.exec "ALTER TYPE #{old_name} RENAME TO #{new_name}"
          end

          private def _effected_tables
            Query["information_schema.columns", adapter]
              .select("table_name, column_name")
              .where { (c("udt_name") == @name.dup) & (c("table_catalog") == Config.db) }
              .pluck(:table_name, :column_name)
          end
        end
      end
    end
  end
end
