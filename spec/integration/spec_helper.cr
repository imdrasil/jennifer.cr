require "spec"
require "../support/matchers"
require "../support/file_system"
require "./shared_helpers"

macro jennifer_adapter
  {% if env("DB") == "postgres" || env("DB") == nil %}
    Jennifer::Adapter.default_adapter.as(Jennifer::Postgres::Adapter)
  {% else %}
    Jennifer::Adapter.default_adapter.as(Jennifer::Mysql::Adapter)
  {% end %}
end

module Spec
  class_getter file_system = FileSystem.new("./")
end

Spec.file_system.tap do |file_system|
  file_system.watch "scripts/models"
  file_system.watch "scripts/migrations"
end

def execute(command, options)
  io = IO::Memory.new

  status = Process.run("#{command} \"${@}\"", options, shell: true, output: io, error: io).exit_status
  puts io.to_s
  {status, io.to_s}
end

def clean(type = DatabaseSeeder.default_interface, &)
  yield
ensure
  DatabaseSeeder.drop(type)
  Spec.file_system.clean
end

def with_connection(&)
  Spec.config_jennifer
  yield
ensure
  Jennifer::Adapter.default_adapter.db.close
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
    if (env = Spec.settings["command_shell"]?).nil?
      "bash"
    else
      env.as_s
    end
  end

  def self.drop(type = default_interface)
    command =
      case type
      when "docker"
        docker_drop_db_command
      when "bash"
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
      when "docker"
        docker_create_db_command
      when "bash"
        bash_create_db_command
      else
        raise "Unknown connection type"
      end
    io = IO::Memory.new
    Process.run(command, shell: true, output: io, error: io).tap { puts io.to_s }
  end

  private def self.docker_drop_db_command
    case Spec.adapter
    when POSTGRES_DB
      common_command = "docker exec -i -e PGPASSWORD=#{Spec.db_password} #{Spec.settings["docker_container"]} dropdb #{Spec.db} -U#{Spec.db_user}"
      common_command = "#{common_command}" if Spec.settings["command_shell_sudo"]?
      common_command
    when MYSQL_DB
      common_command = "echo \"drop database #{Spec.db};\" | docker exec -i #{Spec.settings["docker_container"]} mysql -u#{Spec.db_user}"
      common_command += " -p#{Spec.db_password}" unless Spec.db_password.empty?
      common_command
    else
      Spec.unknown_adapter!
    end
  end

  private def self.bash_drop_db_command
    case Spec.adapter
    when "postgres"
      "PGPASSWORD=#{Spec.db_password} dropdb #{Spec.db} -U#{Spec.db_user} -hlocalhost"
    when "mysql"
      common_command = "echo \"drop database #{Spec.db};\" | mysql -u#{Spec.db_user}"
      common_command += " -p#{Spec.db_password}" unless Spec.db_password.empty?
      common_command
    else
      Spec.unknown_adapter!
    end
  end

  private def self.docker_create_db_command
    case Spec.adapter
    when POSTGRES_DB
      common_command =
        "docker exec -i -e PGPASSWORD=#{Spec.db_password} #{Spec.settings["docker_container"]} createdb #{Spec.db} -U#{Spec.db_user}"
      common_command = "sudo #{common_command}" if Spec.settings["command_shell_sudo"]?
      common_command
    when MYSQL_DB
      common_command = "echo \"create database #{Spec.db};\" | sudo docker exec -i #{Spec.settings["docker_container"]} mysql -u#{Spec.db_user}"
      common_command += " -p#{Spec.db_password}" unless Spec.db_password.empty?
      common_command
    else
      Spec.unknown_adapter!
    end
  end

  private def self.bash_create_db_command
    case Spec.adapter
    when POSTGRES_DB
      "PGPASSWORD=#{Spec.db_password} createdb #{Spec.db} -U#{Spec.db_user} -hlocalhost"
    when MYSQL_DB
      common_command = "mysql -u#{Spec.db_user} -e\"create database #{Spec.db}\""
      common_command += " -p#{Spec.db_password}" unless Spec.db_password.empty?
      common_command
    else
      Spec.unknown_adapter!
    end
  end
end
