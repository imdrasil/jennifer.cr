class Address < Jennifer::Model::Base
  with_timestamps

  mapping(
    id: {type: Int64, primary: true},
    main: Bool,
    street: String,
    contact_id: Int64?,
    details: JSON::Any?,
    created_at: Time?,
    updated_at: Time?
  )

  validates_format :street, /st\.|street/

  belongs_to :contact, Contact

  scope :main { where { _main } }

  after_destroy :increment_destroy_counter

  @@destroy_counter = 0

  def self.destroy_counter
    @@destroy_counter
  end

  def increment_destroy_counter
    @@destroy_counter += 1
  end
end
