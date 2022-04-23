# STI

To use single table inheritance just inherit from your parent model and use regular `%mapping` macro:

```crystal
class Profile < Jennifer::Model::Base
  mapping(
    id: {type: Int64, primary: true},
    login: String,
    contact_id: Int64?,
    type: String
  )

  belongs_to :contact, Contact
end

class FacebookProfile < Profile
  mapping(
    uid: String
  )

  has_and_belongs_to_many :facebook_contacts, Contact, foreign: :profile_id
end

class TwitterProfile < Profile
  mapping(
    email: String
  )
end
```

Requirements:

- created table for STI should include **all** fields of all subclasses (that's why it is cold STI);
- STI table has to have field named as `type` of any string type which will be able to store class name of child models;
- parent class should have definition for `type` field;

To extract from DB several subclasses in one request - just use parent class to query:

```crystal
Profile.all.where { _login.like("%eter%") }
```

Each retrieved object will respect values in `type` field and appropriate class object will be builded (including invoking of `after_initialize` callbacks).
