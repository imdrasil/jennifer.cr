require "spec"
# require "spec2"
require "./config"
require "./models.cr"
require "./factories.cr"

Spec.before_each do
  Jennifer::Adapter.adapter.begin_transaction
end

Spec.after_each do
  Jennifer::Adapter.adapter.rollback_transaction
end

# Spec2.random_order
# Spec2.doc
