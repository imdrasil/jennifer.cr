abstract class ApplicationRecord < Jennifer::Model::Base
  getter? super_class_callback_called = false

  before_create :before_abstract_create

  def before_abstract_create
    @super_class_callback_called = true
  end

  EmptyString = {
    type:    String,
    default: "",
  }

  {% TYPES << "EmptyString" %}
end
