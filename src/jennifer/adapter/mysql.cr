require "mysql"

module Jennifer
  module Adapter
    class Mysql < Base
      include Support

      TYPE_TRANSLATIONS = {
        :int    => "int",
        :string => "varchar",
        :bool   => "bool",
        :text   => "text",
      }

      # runtime queries =========================

      def insert(obj : Model::Base)
        opts = self.class.extract_arguments(obj.attributes_hash)
        query = "INSERT INTO #{obj.class.table_name}(#{opts[:fields].join(", ")}) values (#{self.class.question_marks(opts[:fields].size)})"
        exec query, opts[:args]
      end

      def update(obj : Model::Base)
        opts = self.class.extract_arguments(obj.attributes_hash)
        opts[:args] << obj.primary
        exec "
        UPDATE #{obj.class.table_name} SET #{opts[:fields].map { |f| f + "= ?" }.join(", ")}
        WHERE #{obj.class.primary_field_name} = ?", opts[:args]
      end

      def transaction
        result = false
        @connection.transaction do |tx|
          begin
            result = yield(tx)
            tx.rollback unless result
          rescue
            tx.rollback
          end
        end
        result
      end

      def truncate(klass : Class)
        truncate(klass.table_name)
      end

      def truncate(table_name : String)
        exec "TRUNCATE #{table_name}"
      end

      # is enough unsafe. prefer to use `transaction` with block
      # def transaction(autocommit : Bool = true)
      #  @connection.start_transaction
      #  # exec autocommit ? "BEGIN" : "START TRANSACTION"
      # end

      # is unsafe
      # def commit
      #  @connection.commit_transaction
      #  # exec "COMMIT"
      # end

      # is unsafe
      # def rollback
      #  @connection.rollback_transaction
      #  # exec "ROLLBACK"
      # end

      # ========================================================

      def self.t(field)
        case field
        when Nil
          "NULL"
        when String
          "'" + field + "'"
        else
          field
        end
      end

      def table_exist?(table)
        v = scalar "
          SELECT COUNT(*)
          FROM information_schema.TABLES
          WHERE (TABLE_SCHEMA = '#{Config.db}') AND (TABLE_NAME = '#{table}')"
        v == 1
      end

      def ready_to_migrate!
        unless table_exist?(Migration::Base::TABLE_NAME)
          tb = Migration::TableBuilder::CreateTable.new(Migration::Base::TABLE_NAME)
          tb.integer(:id, {primary: true, auto_increment: true})
            .string(:version, {size: 18})
          create_table(tb)
        end
      end

      def change_table(builder : Migration::TableBuilder::ChangeTable)
        table_name = builder.name
        builder.fields.each do |k, v|
          case k
          when :rename
            exec "ALTER TABLE #{table_name} RENAME #{v[:name]}"
            table_name = v[:name]
          end
        end
      end

      def drop_table(builder : Migration::TableBuilder::DropTable)
        exec "DROP TABLE #{builder.name} IF EXISTS"
      end

      def create_table(builder : Migration::TableBuilder::CreateTable)
        buffer = "CREATE TABLE #{builder.name.to_s} ("
        builder.fields.each do |name, options|
          type = options[:serial]? ? "serial" : options[:sql_type]? || TYPE_TRANSLATIONS[options[:type]]
          suffix = ""
          suffix += "(#{options[:size]})" if options[:size]?
          suffix += " NOT NULL" if options[:null]?
          suffix += " PRIMARY KEY" if options[:primary]?
          suffix += " DEFAULT #{self.class.t(options[:default])}" if options[:default]?
          suffix += " AUTO_INCREMENT" if options[:auto_increment]?
          buffer += "#{name.to_s} #{type}#{suffix},"
        end
        exec buffer[0...-1] + ")"
      end

      def self.drop_database
        db_connection do |db|
          db.exec "DROP DATABASE #{Config.db}"
        end
      end

      def self.create_database
        db_connection do |db|
          db.exec "CREATE DATABASE #{Config.db}"
        end
      end
    end
  end
end
