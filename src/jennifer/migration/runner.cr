module Jennifer
  module Migration
    module Runner
      MIGRATION_DATE_FORMAT = "%Y%m%d%H%M%S%L"

      def self.migrate(count)
        performed = false
        default_adapter.ready_to_migrate!
        return if ::Jennifer::Migration::Base.migrations.empty?
        interpolation = {} of String => typeof(Base.migrations[0])
        Base.migrations.each { |m| interpolation[m.version] = m }

        pending = interpolation.keys - Version.all.pluck(:version).map(&.as(String))
        return if pending.empty?
        broken = Version.where { _version.in(pending) }.pluck(:version).map(&.as(String))
        unless broken.empty?
          puts "Can't run migrations because some of them are older then master version.\nThey are:"
          broken.sort.each do |v|
            puts "- #{v}"
          end
          return
        end

        i = 0
        pending.sort.each do |p|
          return if count > 0 && i >= count
          performed = true
          klass = interpolation[p]
          puts "Migration #{klass}"
          instance = klass.new
          begin
            instance.up
          rescue e
            puts "rollbacked"
            puts e.message
            raise e
          end
          Version.create({version: p})
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
        r = default_adapter_class.drop_database
        puts "DB is dropped!"
      end

      def self.rollback(options : Hash(Symbol, DBAny))
        processed = true
        default_adapter.ready_to_migrate!
        return if ::Jennifer::Migration::Base.migrations.empty? || !Version.all.exists?
        interpolation = {} of String => typeof(Base.migrations[0])
        Base.migrations.each { |m| interpolation[m.version] = m }

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
          klass = interpolation[v]
          klass.new.down
          Version.all.where { _version == v }.delete
          processed = true
          puts "Dropped migration #{v}"
        end
      rescue e
        puts e.message
      ensure
        # TODO: generate schema for each adapter
        default_adapter_class.generate_schema if processed
      end

      def self.load_schema
        return if config.skip_dumping_schema_sql
        # TODO: load schema for each adapter
        default_adapter_class.load_schema
        puts "Schema loaded"
      end

      def self.generate(name)
        time = Time.now.to_s(MIGRATION_DATE_FORMAT)
        migration_name = name.camelcase + time
        str = "class #{migration_name} < Jennifer::Migration::Base\n  def up\n  end\n\n  def down\n  end\nend\n"
        File.write(File.join(Config.migration_files_path.to_s, "#{time}_#{name.underscore}.cr"), str)
        puts "Migration #{migration_name} was generated"
      rescue e
        puts e.message
      end

      def self.config
        Config.instance
      end

      def self.default_adapter
        Adapter.default_adapter
      end

      def self.default_adapter_class
        Adapter.default_adapter_class
      end
    end
  end
end
