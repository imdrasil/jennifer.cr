# Configuration

Put
```crystal
require "jennifer/adapter/mysql" # for mysql
require "jennifer/adapter/postgres" # for postgres
require "jennifer" 
```

> Be attentive - adapter should be required before main staff. Only one adapter can be required at once.

This should be done before you load your application configurations (or at least models). Now configuration could be loaded from yaml file:

```crystal
Jennifer::Config.read("./spec/fixtures/database.yml", :development) 
```

Second argument represents environment and just use it as namespace key grapping values from yml.

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

All configs:

| config | default value |
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
| `max_pool_size` | 5 |
| `initial_pool_size` | 1 |
| `max_idle_pool_size` | 1 |
| `retry_attempts` | 1 |
| `checkout_timeout` | 5.0 |
| `retry_delay` | 1.0 |

> `port = -1` will provide connection URI without port mention

Also configuration can be parsed directly from URI:

```crystal
db_uri = "mysql://root@somehost/some_database?max_pool_size=111&initial_pool_size=222&max_idle_pool_size=333&retry_attempts=444&checkout_timeout=555&retry_delay=666"
Jennifer::Config.from_uri(db)
```

#### Logging

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
