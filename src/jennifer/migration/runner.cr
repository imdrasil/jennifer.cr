require "../support"

module Jennifer
  module Migration
    module Runner
      def self.migrate
        Adapter.adapter.ready_to_migrate!
        return if ::Jennifer::Migration::Base::REGISTERED_MIGRATIONS.empty?
        interpolation = {} of String => typeof(Base::REGISTERED_MIGRATIONS[0])
        Base::REGISTERED_MIGRATIONS.each { |m| interpolation[m.to_s[-18..-1]] = m }
        pending = interpolation.keys - Version.all.pluck(:version).flat_map(&.values)
        return if pending.empty?
        brocken = Version.where { version.in(pending) }.pluck(:version).flat_map(&.values)
        unless brocken.empty?
          puts "Can't run migrations because some of them are older then relase version."
          puts "They are:"
          brocken.each do |v|
            puts "- #{v}"
          end
          return
        end

        pending.each do |p|
          klass = interpolation[p]
          puts "Migration #{klass}"
          instance = klass.new
          begin
            instance.up
          rescue e
            instance.down
            puts "rollbacked"
            raise e
          end
          Version.create(version: p)
        end
      end

      def self.create
        puts Adapter.adapter_class.create_database
        puts "DB created!"
      end

      def self.drop
        puts Adapter.adapter_class.drop_database
        puts "DB droped"
      end

      def self.generate(name)
        time = Time.now.to_s("%Y%m%d%H%M%S%L")
        str = "class #{name.camelcase + time} < Jennifer::Migration::Base\n  def up\n  end\n\n  def down\n  end\nend"
        File.write(File.join(Config.migration_files_path.to_s, "#{time}_#{name.underscore}.cr"), str)
      end
    end
  end
end
