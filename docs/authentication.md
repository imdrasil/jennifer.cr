# Authentication

To add authentication to your user model just use `Jennifer::Model::Authentication` module's `with_authentication` macro:

```crystal
require "jennifer/model/authentication"

class User < Jennifer::Model::Base
  include Jennifer::Model::Authentication

  with_authentication

  mapping(
    id: Primary64,
    email: {type: String, default: ""},
    password_digest: {type: String, default: ""},
    password: Password,
    password_confirmation: { type: String?, virtual: true }
  )
end
```

`Password` in the `password` field definition is actually `Jennifer::Model::Authentication::Password` constant which includes definition for virtual password attribute. It looks like:

```crystal
Password = {
  type:    String?,
  virtual: true,
  setter:  false,
}
```

Mapping automatically resolves it to its definition. At the moment only top level non generic definition could be used, e.g. `password: { type: Password }` and `password: Password?` are not supported.

For authentication `Crypto::Bcrypt::Password` is used. This mechanism requires you to have a `password_digest`, `password`, `password_confirmation` attributes defined in your mapping. This attribute can be customized - `with_authentication` macro accepts next arguments:

- `password` - presents string based raw password attribute name;
- `password_digest` - presents string based encrypted password.

> NOTE: `password_confirmation` attribute name is generated based on the `password` value + `_confirmation`.

The following validations are added automatically:

- password must be present on creation;
- password length should be less than or equal to 51 characters;
- confirmation of password (using a password_confirmation attribute).

If password confirmation validation is not needed, simply leave out the value for password_confirmation (i.e. don't provide a form field for it). When this attribute has a nil value, the validation will not be triggered.

```crystal
user = User.new(name: "david")
user.password = ""
user.password_confirmation = "nomatch"
user.save # => false, password required

user.password = "mUc3m00RsqyRe"
user.save # => false, confirmation doesn't match
user.password_confirmation = 'mUc3m00RsqyRe'
user.save # => true

user.authenticate("notright")  # => false
user.authenticate("mUc3m00RsqyRe") # => user
User.all.where { _name == "david" }.first.try(&.authenticate("notright")) # nil
User.all.where { _name == "david" }.first.try(&.authenticate("mUc3m00RsqyRe")) # => User
```
