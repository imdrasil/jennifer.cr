module Jennifer
  module Migration
    # This modules is responsible for processing database migration operations like creation,
    # dropping and migration.
    module Runner
      # Invokes migrations. *count* with negative or zero value will invoke all pending migrations.
      def self.migrate(count : Int = -1, adapter : Adapter::Base = default_adapter)
        performed = false
        Version.adapter = adapter
        adapter.ready_to_migrate!
        pending_versions = get_pending_versions
        return if pending_versions.empty?

        assert_outdated_pending_migrations pending_versions
        migrations = Base.migrations

        pending_versions.each_with_index do |version, i|
          return if count > 0 && i >= count

          process_up_migration(migrations[version].new, adapter)
          performed = true
        end
      ensure
        adapter.generate_schema if performed && !adapter.config.skip_dumping_schema_sql
      end

      # Creates database using given *adapter*.
      #
      # If database already exists - do nothing.
      #
      # By default use application default adapter.
      def self.create(adapter : Adapter::Base = default_adapter)
        if adapter.database_exists?
          puts "#{adapter.config.db} is already exists"
        else
          adapter.create_database
          puts "#{adapter.config.db} is created!"
        end
      end

      # Drops database using given *adapter*.
      #
      # By default use application default adapter.
      def self.drop(adapter : Adapter::Base = default_adapter)
        adapter.drop_database
        puts "#{adapter.config.db} is dropped!"
      end

      # Rollbacks migrations.
      #
      # Allowed options:
      # - *count* - count of migrations to be rolled back
      # - *to* - migration timestamp to which database should be rolled back
      def self.rollback(options : Hash(Symbol, DBAny), *, adapter : Adapter::Base = default_adapter)
        processed = true
        adapter.ready_to_migrate!
        migrations = Base.migrations
        return if migrations.empty? || !Version.all.exists?

        versions =
          if options[:count]?
            Version.all.order(version: :desc).limit(options[:count].to_i).pluck(:version)
          elsif options[:to]?
            v = options[:to].to_s
            Version.all.order(version: :desc).where { _version > v }.pluck(:version)
          else
            raise ArgumentError.new
          end

        versions.each do |version|
          process_down_migration(migrations[version].new, adapter)
          processed = true
        end
      ensure
        adapter.generate_schema if processed && !adapter.config.skip_dumping_schema_sql
      end

      # Loads schema from the SQL schema file.
      def self.load_schema(adapter : Adapter::Base = default_adapter)
        return if adapter.config.skip_dumping_schema_sql

        adapter.load_schema
        puts "Schema loaded"
      end

      private def self.default_adapter
        Adapter.default_adapter
      end

      # NOTE: pending versions are memorized so reloading should be performed manually.
      private def self.get_pending_versions
        pending_versions = (Base.versions - Version.list).sort!
        pending_versions
      end

      private def self.default_adapter_class
        Adapter.default_adapter_class
      end

      private def self.process_up_migration(migration, adapter)
        optional_transaction(migration) do
          process_with_announcement(migration, :up) do
            migration.up
            Version.create(version: migration.class.version)
          end
        end
      rescue e
        optional_transaction(migration) do
          if adapter.config.migration_failure_handler_method.reverse_direction?
            migration.down
          elsif adapter.config.migration_failure_handler_method.callback?
            migration.after_up_failure
          end
        end

        raise e
      end

      private def self.process_down_migration(migration, adapter)
        optional_transaction(migration) do
          process_with_announcement(migration, :down) do
            migration.down
            Version.all.where { _version == migration.class.version }.delete
          end
        end
      rescue e
        optional_transaction(migration) do
          if adapter.config.migration_failure_handler_method.reverse_direction?
            migration.up
          elsif adapter.config.migration_failure_handler_method.callback?
            migration.after_down_failure
          end
        end

        raise e
      end

      private def self.process_with_announcement(migration, direction)
        words =
          case direction
          when :up
            {start: "migrating", end: "migrated"}
          else
            {start: "reverting", end: "reverted"}
          end
        header = "== #{migration.class.version} #{migration.class}:"
        puts "#{header} #{words[:start]}" if Config.config.verbose_migrations
        time = Time.measure { yield }
        puts "#{header} #{words[:end]} (#{time.milliseconds} ms)\n" if Config.config.verbose_migrations
      end

      private def self.assert_outdated_pending_migrations(pending_versions)
        return if !Version.all.exists? || Config.config.allow_outdated_pending_migration

        db_version = Version.all.order(version: :desc).first!.version
        broken = pending_versions.select { |version| version < db_version }
        return if broken.empty?

        raise <<-MESSAGE
          Can't run migrations because some of them are older then release version.
          They are:
          #{broken.map { |v| "- #{v}" }.join("\n")}
        MESSAGE
      end

      private def self.optional_transaction(migration)
        if migration.class.with_transaction?
          Model::Base.transaction { yield }
        else
          yield
        end
      end
    end
  end
end
