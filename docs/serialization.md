# Serialization

There are multiple approaches to implement model serialization to a required format.

## General

Jennifer defines some hidden instance attributes in defined models for own use. Sometimes we would like to operate with a class where we have full access to all defined attributes/methods. For this case the easiest way is to use [JenniferTwin](https://github.com/imdrasil/jennifer_twin). Using it you can dump Jennifer model instance to a one that is totally under your control. One of the cases when this approach may come in handy when we would like to use attribute annotations, like [MessagePack::Serializable](https://github.com/crystal-community/msgpack-crystal) or [JSON::Serializable](https://crystal-lang.org/api/0.31.1/JSON/Serializable.html).

```crystal
class User < Jennifer::Model::Base
  mapping(
    id: Primary32,
    name: String?,
    age: Int32?,
    password_hash: String?
  )
end

class UserTwin
  include JenniferTwin
  include JSON::Serializable

  map_fields(User, {
    name: { key: :full_name },
    password_hash: { ignore: true }
  })

  setter full_name

  @[JSON::Field(emit_null: false)]
  @age : Int32?
end

user = User.all.first # <User:0x000000000010 id: 1, name: "User 8", age: nil, password_hash: "<hash>">
user_twin = UserTwin.new(user) # <UserTwin:0x000000000020 @id=1, @full_name="User 8", @age=nil>
user_twin.to_json # => %({"id":1,"full_name":"User 8","age":null})
```

Also you can easily convert such twin back to model

```crystal
user_twin.full_name = "New Name"
user_twin.to_modal # <User:0x000000000030 id: nil, name: "New Name", age: nil, password_hash: nil>
```

## JSON

For JSON serialization there are 2 options (apart from described above).

### `Model::Base#to_h`

If you need just to dump all non virtual fields to a JSON string - use `Jennifer::Model::Base#to_h` to get `Hash(Symbol, T::AttrType)` (or `#to_str_h` to get `Hash(String, T::AttrType)`) and then `#to_json` to get a JSON string. The disadvantages of this approach are obvious - **all** non virtual fields are serialized. This can be partially resolved by manual deleting/adding entries by keys (as before final serialization we get hash).

```crystal
user = User.all.first # <User:0x000000000010 id: 1, name: "User 8", age: nil, password_hash: "<hash>">
hash = user.to_h # => {:id => 1, :full_name => "User 8", :age => null}
hash.delete(:age) if hash[:age].nil?
hash.to_json # => %({"id":1,"full_name":"User 8"})
```

### Serializer

As an alternate you can use [Serializer](https://github.com/imdrasil/serializer) library dedicated to this purpose - serialize Jennifer object relations. Apart from simple attribute mapping/renaming you can also specify all relationships (`has_many`/`belongs_to`/`has_one`), override methods, dynamically specify which attributes/relations should be serialized.

```crystal
class CommentSerializer < Serializer::Base(Comment)
  attribute :text

  belongs_to :post, PostSerializer
end

class PostSerializer < Serializer::Base(Post)
  attribute :title, :Title, if: :test_title
  attribute :body
  attribute :category

  has_many :comments, CommentSerializer

  def test_title(object, options)
    options.nil? || !options[:test]?
  end

  def category
    12
  end
end

ModelSerializer.new(Post.last).serialize(
  except: [:category],
  includes: {
    :comments => [:post], # you can specify relations any level deep
  },
  meta: { :page => 0 } # and add meta data
)
```

More descriptions you can find on it's github page.
