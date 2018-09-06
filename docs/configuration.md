# Configuration

Put

```crystal
require "jennifer"
require "jennifer/adapter/mysql" # for mysql
require "jennifer/adapter/postgres" # for postgres
```

> Be attentive - adapter should be required **after** main staff. From `0.5.0` several adapters could be required at the same time.

This should be done before you load your application configurations (or at least models). Now configuration could be loaded from yaml file:

```crystal
Jennifer::Config.read("./spec/fixtures/database.yml", :development)
```

Second argument represents environment and just use it as namespace key grepping values from yml.

```yaml
defaults : &defaults
  host: localhost
  adapter: postgres
  user: developer
  password: 1qazxsw2
  migration_files_path: ./examples/migrations

development:
  db: jennifer_develop
  <<: *defaults

test:
  db: jennifer_test
  <<: *defaults
```

Also dsl could be used:

```crystal
Jennifer::Config.configure do |conf|
  conf.host = "localhost"
  conf.user = "root"
  conf.password = ""
  conf.adapter = "mysql"
  conf.db = "crystal"
  conf.migration_files_path = "./examples/migrations"
end
```

If your configurations aren't stored on the top level - you can manipulate which document subpart will be used to parse parameters:

```crystal
Jennifer::Config.read("./spec/fixtures/database.yml", &.["database"]["development"])
```

Also configuration can be parsed directly from URI:

```crystal
db_uri = "mysql://root@somehost/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555&retry_delay=666"
Jennifer::Config.from_uri(db)
```

## Supported configuration parameters

| Config | Default value |
| --- | --- |
| `migration_files_path` | `"./db/migrations"` |
| `structure_folder` | parent folder of `migration_files_path` |
| `host` | `"localhost"` |
| `port` | -1 |
| `logger` | `Logger.new(STDOUT)` |
| `schema` | `"public"` |
| `user` | - |
| `password` | - |
| `db` | - |
| `adapter` | - |
| `max_pool_size` | 1 |
| `initial_pool_size` | 1 |
| `max_idle_pool_size` | 1 |
| `retry_attempts` | 1 |
| `checkout_timeout` | 5.0 |
| `retry_delay` | 1.0 |
| `local_time_zone_name` | default time zone name |
| `skip_dumping_schema_sql` | `false` |
| `command_shell` | `"bash"` |
| `docker_container` | `""` |
| `docker_source_location` | `""` |
| `command_shell_sudo` | `false` |

> It is highly recommended to set `max_idle_pool_size = max_pool_size = initial_pool_size` to prevent blowing up count of DB connections. For any details take a look at `crystal-db` [issue](https://github.com/crystal-lang/crystal-db/issues/77).

To avoid port usage set it to `-1`. For doing same with the password - assign to it blank value (`""`). Empty string also turns off `structure_folder` config.

Also configuration can be parsed directly from URI:

```crystal
db_uri = "mysql://root@somehost/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555&retry_delay=666"
Jennifer::Config.from_uri(db)
```

Also take into account - some configs can't be initialized using URI string or yaml file but all of them always can be initialized using `Jennifer::Config.configure`. Here is the list of such configs:

| Config | YAML | URI |
| --- | --- | --- |
| `logger` | ❌ | ❌ |
| `migration_file_path` | ✔ | ❌ |
| `schema` | ✔ | ❌ |
| `local_time_zone_name` | ✔ | ❌ |
| `schema` | ✔ | ❌ |
| `structure_folder` | ✔ | ❌ |
| `skip_dumping_schema_sql` | ✔ | ❌ |
| `docker_container` | ✔ | ❌ |
| `docker_source_location` | ✔ | ❌ |
| `command_shell_sudo` | ✔ | ❌ |

From `0.5.1` `Jennifer::Config` has started working under singleton pattern instead of using class as a container for all configuration properties.

## Logging

Jennifer uses regular Crystal logging mechanism so you could specify your own logger or formatter:

```crystal
# Here is default logger configuration
Jennifer::Config.configure do |conf|
  conf.logger = Logger.new(STDOUT)

  conf.logger.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
    io << datetime << ": " << message
  end
  conf.logger.level = Logger::DEBUG
end
```

## Command Shell

Some database related operations need to be performed by invoking bash command (like creating or dropping database). By default bash shell is used for such purposes under user invoking this operation, but this may be specified.

To specify another command shell set `command_shell` configuration to another registered one. One more onboard command shell is `"docker"` but you mau also define your own. To do this you should inherit from `Jennifer::Adapter::ICommandShell` abstract class and register it:

```crystal
class MySimpleDocker < Jennifer::Adapter::ICommandShell
  def execute(command)
    command_string = String.build do |io|
      io << "sudo " if config.command_shell_sudo
      io << "docker exec -i "
      io << config.docker_container
      io << " "
      io << command.executable
      io << " "
      io << OPTIONS_PLACEHOLDER
    end
    invoke(command_string, command.options)
  end
end

Jennifer::Adapter::DBCommandInterface.register_shell("my_docker", MySimpleDocker)
```

`command_shell_sudo` enables using `sudo` in command line. This will force you to enter a password for your admin user.
