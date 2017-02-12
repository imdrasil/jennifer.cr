require "spec"
# require "spec2"
require "../src/jennifer"
require "./models.cr"
require "./factories.cr"
# Spec2.random_order
# Spec2.doc

Jennifer::Config.configure do |conf|
  conf.host = "localhost"
  conf.user = "root"
  conf.password = ""
  conf.adapter = "mysql"
  conf.db = "prequel_test"
end

Jennifer::Migration::Runner.migrate

# Spec.before_each do
# Jennifer::Adapter.adapter.transaction(false)
# end

# Spec.after_each do
# Jennifer::Adapter.adapter.rollback
# end
