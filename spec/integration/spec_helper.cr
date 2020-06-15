require "spec"
require "../support/matchers"

POSTGRES_DB = "postgres"
MYSQL_DB = "mysql"

def execute(command, options)
  io = IO::Memory.new

  status = Process.run("#{command} \"${@}\"", options, shell: true, output: io, error: io).exit_status
  {status, io.to_s}
end

def clean(type = DatabaseSeeder.default_interface)
  yield
ensure
  DatabaseSeeder.drop(type)
end

def db_specific(mysql, postgres)
  case Spec.adapter
  when POSTGRES_DB
    postgres.call
  when MYSQL_DB
    mysql.call
  else
    raise "Unknown adapter type"
  end
end

class DatabaseSeeder
  def self.default_interface
    db_specific(mysql: -> { :docker }, postgres: -> { :bash })
  end

  def self.drop(type = default_interface)
    command =
      case type
      when :docker
        docker_drop_db_command
      when :bash
        bash_drop_db_command
      else
        raise "Unknown connection type"
      end
    io = IO::Memory.new
    Process.run(command, shell: true, output: io, error: io).tap { puts io.to_s }
  end

  def self.create(type = default_interface)
    command =
      case type
      when :docker
        docker_create_db_command
      when :bash
        bash_create_db_command
      else
        raise "Unknown connection type"
      end
    io = IO::Memory.new
    Process.run(command, shell: true, output: io, error: io).tap { puts io.to_s }
  end

  private def self.db
    DEFAULT_DB
  end

  private def self.docker_drop_db_command
    case Spec.adapter
    # when POSTGRES_DB
    #   "PGPASSWORD=#{password} dropdb #{db} -U#{user}"
    when MYSQL_DB
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

  private def self.docker_create_db_command
    case Spec.adapter
    # when POSTGRES_DB
    #   "PGPASSWORD=#{db_password} createdb #{db} -U#{db_user}"
    when MYSQL_DB
      common_command = "echo \"create database #{db};\" | sudo docker exec -i #{DEFAULT_DOCKER_CONTAINER} mysql -u#{db_user}"
      common_command += " -p#{db_password}" unless db_password.empty?
      common_command
    else
      unknown_adapter!
    end
  end

  private def self.bash_create_db_command
    case Spec.adapter
    when POSTGRES_DB
      "PGPASSWORD=#{db_password} createdb #{db} -U#{db_user}"
    when MYSQL_DB
      common_command = "mysql -u#{db_user} -e\"create database #{db}\""
      common_command += " -p#{db_password}" unless db_password.empty?
      common_command
    else
      unknown_adapter!
    end
  end

  private def self.db_user
    ENV["DB_USER"]? ||
      case Spec.adapter
      when POSTGRES_DB
        "developer"
      when MYSQL_DB
        "root"
      else
        unknown_adapter!
      end
  end

  private def self.db_password
    ENV["DB_PASSWORD"]? ||
      case Spec.adapter
      when POSTGRES_DB
        "1qazxs2"
      when MYSQL_DB
        ""
      else
        unknown_adapter!
      end
  end

  private def self.unknown_adapter!
    raise "Unknown adapter"
  end
end
