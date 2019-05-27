module Jennifer
  module Migration
    # :nodoc:
    module Runner
      @@pending_versions = [] of String

      # Invokes migrations. *count* with negative or zero value will invoke all pending migrations.
      def self.migrate(count : Int)
        performed = false
        default_adapter.ready_to_migrate!
        migrations = Base.migrations
        return if migrations.empty? || pending_versions.empty?
        assert_outdated_pending_migrations

        pending_versions.each_with_index do |version, i|
          return if count > 0 && i >= count
          process_up_migration(migrations[version].new)
          performed = true
        end
      rescue e
        puts e.message
        puts e.backtrace.join("\n")
      ensure
        # TODO: generate schema for each adapter
        default_adapter.class.generate_schema if performed && !Config.skip_dumping_schema_sql
      end

      # Invokes all migrations.
      def self.migrate
        migrate(-1)
      end

      # Creates database.
      def self.create
        # TODO: allow to specify adapter
        if default_adapter_class.database_exists?
          puts "#{Config.db} is already exists"
        else
          default_adapter_class.create_database
          puts "#{Config.db} is created!"
        end
      end

      # Drops database.
      def self.drop
        # TODO: allow to specify adapter
        r = default_adapter_class.drop_database
        puts "#{Config.db} is dropped!"
      end

      # Rollbacks migrations.
      #
      # Allowed options:
      # - *count*
      # - *to*
      def self.rollback(options : Hash(Symbol, DBAny))
        processed = true
        default_adapter.ready_to_migrate!
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
          process_down_migration(migrations[version].new)
          processed = true
        end
      rescue e
        puts e.message
      ensure
        # TODO: generate schema for each adapter
        default_adapter_class.generate_schema if processed && !Config.skip_dumping_schema_sql
      end

      # Loads schema from the SQL schema file.
      def self.load_schema
        return if Config.skip_dumping_schema_sql
        # TODO: load schema for each adapter
        default_adapter_class.load_schema
        puts "Schema loaded"
      end

      private def self.default_adapter
        Adapter.default_adapter
      end

      # NOTE: pending versions are memorized so reloading should be performed manually.
      private def self.pending_versions
        @@pending_versions = (Base.versions - Version.list).sort! if @@pending_versions.empty?
        @@pending_versions
      end

      private def self.default_adapter_class
        Adapter.default_adapter_class
      end

      private def self.process_up_migration(migration)
        transaction do
          process_with_announcement(migration, :up) do
            migration.up
            Version.create(version: migration.class.version)
          end
        end
      rescue e
        transaction do
          case Config.migration_failure_handler_method
          when "reverse_direction"
            migration.down
          when "callback"
            migration.after_up_failure
          end
        end

        raise e
      end

      private def self.process_down_migration(migration)
        transaction do
          process_with_announcement(migration, :down) do
            migration.down
            Version.all.where { _version == migration.class.version }.delete
          end
        end
      rescue e
        transaction do
          case Config.migration_failure_handler_method
          when "reverse_direction"
            migration.up
          when "callback"
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
        puts  "#{header} #{words[:start]}" if Config.config.verbose_migrations
        time = Time.measure do
          yield
        end
        puts  "#{header} #{words[:end]} (#{time.milliseconds} ms)" if Config.config.verbose_migrations
        puts if Config.config.verbose_migrations
      end

      private def self.assert_outdated_pending_migrations
        return unless Version.all.exists?
        db_version = Version.all.order(version: :desc).limit(1).pluck(:version)[0].as(String)
        broken = pending_versions.select { |version| version < db_version }
        unless broken.empty?
          raise <<-MESSAGE
          Can't run migrations because some of them are older then release version.
          They are:
          #{broken.map { |v| "- #{v}" }.join("\n")}
          MESSAGE
        end
      end

      private def self.transaction
        Model::Base.transaction { yield }
      end
    end
  end
end
