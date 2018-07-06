require "spec"
require "../support/matchers"

def execute(command, options)
  io = IO::Memory.new

  status = Process.run("#{command} \"${@}\"", options, shell: true, output: io, error: io).exit_status
  {status, io.to_s}
end

def clean(type = :bash)
  yield
ensure
  DatabaseSeeder.drop(type)
end

class DatabaseSeeder
  def self.drop(type = :bash)
    command =
      case type
      when :docker
        docker_drop_db_command
      when :bash
        bash_drop_db_command
      else
        raise "Unknown connection type"
      end
    Process.run(command, shell: true)
  end

  def self.create(type = :bash)
    config = Jennifer::Config
    command =
      case Spec.adapter
      when "postgres"
        "PGPASSWORD=#{db_password} createdb #{db} -U#{db_user}"
      when "mysql"
        common_command = "echo \"create database #{db};\" | mysql -u#{db_user}"
        common_command += " -p#{db_password}" unless db_password.empty?
        common_command
      else
        unknown_adapter!
      end
    Process.run(command, shell: true)
  end

  private def self.db
    DEFAULT_DB
  end

  private def self.docker_drop_db_command
    case Spec.adapter
    # when "postgres"
    #   "PGPASSWORD=#{password} dropdb #{db} -U#{user}"
    when "mysql"
      common_command = "echo \"drop database #{db};\" | sudo docker exec -i #{DEFAULT_DOCKER_CONTAINER} mysql -u#{db_user}"
      common_command += " -p#{db_password}" unless db_password.empty?
      common_command
    else
      unknown_adapter!
    end
  end

  private def self.bash_drop_db_command
    case Spec.adapter
    when "postgres"
      "PGPASSWORD=#{db_password} dropdb #{db} -U#{db_user}"
    when "mysql"
      common_command = "echo \"drop database #{db};\" | mysql -u#{db_user}"
      common_command += " -p#{db_password}" unless db_password.empty?
      common_command
    else
      unknown_adapter!
    end
  end

  private def self.db_user
    ENV["DB_USER"]? ||
      case Spec.adapter
      when "postgres"
        "developer"
      when "mysql"
        "root"
      else
        unknown_adapter!
      end
  end

  private def self.db_password
    ENV["DB_PASSWORD"]? ||
      case Spec.adapter
      when "postgres"
        "1qazxs2"
      when "mysql"
        ""
      else
        unknown_adapter!
      end
  end

  private def self.unknown_adapter!
    raise "Unknown adapter"
  end
end
