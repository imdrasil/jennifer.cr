module Jennifer
  module Migration
    module Runner
      MIGRATION_DATE_FORMAT = "%Y%m%d%H%M%S%L"

      def self.adapter(config_key)
        Jennifer::Adapter::AdapterRegistry.adapter(config_key)
      end

      def self.migrate(config_key = "default", count = 1)
        performed = false
        puts "Attempting to migrate using config '#{config_key}'"
        adapter(config_key).ready_to_migrate!

        if ::Jennifer::Migration::Base.migrations.empty?
          puts "No migrations found."
          return
        end

        interpolation = {} of String => typeof(Base.migrations[0])
        Base.migrations.each { |m| interpolation[m.version] = m }

        pending = interpolation.keys - Version.all.pluck(:version).map(&.as(String))
        if pending.empty?
          puts "There are no pending migrations"
          return
        end

        broken = Version.where { _version.in(pending) }.pluck(:version).map(&.as(String))
        unless broken.empty?
          puts "Can't run migrations because some of them are older then relase version.\nThey are:"
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
            puts "Error during migration - rolled back"
            puts e.message
            raise e
          end
          Version.create({version: p})
        end
      rescue e
        puts e.message
        puts e.backtrace.join("\n")
      ensure
        adapter(config_key).generate_schema if performed
      end

      def self.create(config_key = "default")
        r = adapter(config_key).create_database
        puts "DB created!" # todo: refactor creation to verify that db is created.
        r
      end

      def self.drop(config_key = "default")
        puts adapter(config_key).drop_database
        puts "DB droped"
      end

      def self.rollback(config_key = "default", options : Hash(Symbol, DBAny) = {} of Symbol => DBAny)
        processed = true
        adapter(config_key).ready_to_migrate!
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
          puts "Droped migration #{v}"
        end
      rescue e
        puts "Error during migration rollback"
        puts e.message
      ensure
        adapter(config_key).generate_schema if processed
      end

      def self.load_schema(config_key = "default")
        adapter(config_key).load_schema
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
    end
  end
end
