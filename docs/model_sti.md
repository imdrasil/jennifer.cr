#### STI

Single table inheritance could be used in next way:
```crystal
class Profile < Jennifer::Model::Base
  mapping(
    id: {type: Int32, primary: true},
    login: String,
    contact_id: Int32?,
    type: String
  )

  belongs_to :contact, Contact
end

class FacebookProfile < Profile
  sti_mapping(
    uid: String
  )

  has_and_belongs_to_many :facebook_contacts, Contact, foreign: :profile_id
end

class TwitterProfile < Profile
  sti_mapping(
    email: String
  )
end
```

Subclass extends superclass definition with new fields and use string fild `type` to indentify itself.

> Now `Profile.all` will return objects of `Profile` class not taking into account `type` field.
