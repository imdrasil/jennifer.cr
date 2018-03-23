module Jennifer
  module Migration
    module Runner
      MIGRATION_DATE_FORMAT = "%Y%m%d%H%M%S%L"

      @@migration_classes = {} of String => Base.class
      @@pending_versions = [] of String

      def self.migration_classes
        if @@migration_classes.empty?
          Base.migrations.each { |m| @@migration_classes[m.version] = m }
        end
        @@migration_classes
      end

      def self.pending_versions
        if @@pending_versions.empty?
          @@pending_versions = (migration_classes.keys - Version.list).sort!
        end
        @@pending_versions
      end

      # Invokes migrations. *count* with negative or zero value will invoke all pending migrations.
      def self.migrate(count : Int)
        performed = false
        default_adapter.ready_to_migrate!
        return if Base.migrations.empty? || pending_versions.empty?
        assert_outdated_pending_migrations

        pending_versions.each_with_index do |p, i|
          return if count > 0 && i >= count
          process_up_migration(migration_classes[p].new)
          performed = true
        end
      rescue e
        puts e.message
        puts e.backtrace.join("\n")
      ensure
        # TODO: generate schema for each adapter
        default_adapter.class.generate_schema if performed
      end

      def self.migrate
        migrate(-1)
      end

      def self.create
        # TODO: allow to specify adapter
        r = default_adapter_class.create_database
        puts "DB is created!"
      end

      def self.drop
        # TODO: allow to specify adapter
        default_adapter_class.drop_database
        puts "DB is dropped!"
      end

      def self.rollback(options : Hash(Symbol, DBAny))
        processed = true
        default_adapter.ready_to_migrate!
        return if Base.migrations.empty? || !Version.all.exists?

        versions =
          if options[:count]?
            Version.all.order(version: :desc).limit(options[:count].to_i).pluck(:version)
          elsif options[:to]?
            v = options[:to].to_s
            Version.all.order(version: :desc).where { _version > v }.pluck(:version)
          else
            raise ArgumentError.new
          end

        versions.each do |v|
          process_down_migration(migration_classes[v].new)
          processed = true
        end
      rescue e
        puts e.message
      ensure
        # TODO: generate schema for each adapter
        default_adapter_class.generate_schema if processed
      end

      def self.assert_outdated_pending_migrations
        return unless Version.all.exists?
        db_version = Version.all.order(version: :desc).limit(1).pluck(:version)[0].as(String)
        brocken = pending_versions.select { |version| version < db_version }
        unless brocken.empty?
          message = <<-MESSAGE
          Can't run migrations because some of them are older then relase version.
          They are:
          #{brocken.map { |v| "- #{v}" }.join("\n")}
          MESSAGE
          raise message
        end
      end

      def self.load_schema
        # TODO: add loading schema for each adapter
        default_adapter_class.load_schema
      end

      def self.generate(name : String)
        time = Time.now.to_s(MIGRATION_DATE_FORMAT)
        migration_name = name.camelcase
        str = <<-MIGRATION
        class #{migration_name} < Jennifer::Migration::Base
          def up
          end

          def down
          end
        end

        MIGRATION
        File.write(File.join(Config.migration_files_path.to_s, "#{time}_#{migration_name.underscore}.cr"), str)
        puts "Migration #{migration_name.underscore} was generated"
      end

      def self.default_adapter
        Adapter.default_adapter
      end

      def self.default_adapter_class
        Adapter.default_adapter_class
      end

      private def self.process_up_migration(migration)
        migration_processed = false
        begin
          transaction { migration.up }
          Version.create(version: migration.class.version)
          migration_processed = true
          puts "Migration #{migration.class}"
        ensure
          transaction do
            case Config.migration_failure_handler_method
            when "reverse_direction"
              migration.down
            when "callback"
              migration.after_up_failure
            end
          end
        end
      end

      private def self.process_down_migration(migration)
        migration_processed = false
        begin
          transaction { migration.down }
          Version.all.where { _version == migration.class.version }.delete
          migration_processed = true
          puts "Droped migration #{migration.class}"
        ensure
          transaction do
            case Config.migration_failure_handler_method
            when "reverse_direction"
              migration.up
            when "callback"
              migration.after_down_failure
            end
          end
        end
      end

      private def self.transaction
        Model::Base.transaction { yield }
      end
    end
  end
end
