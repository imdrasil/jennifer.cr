# Relationships

A relationship is a connection between two models. They make common operations simpler and easier in your code. For example, consider a simple application that includes a model for authors and a model for books. Each author can have many books. Without relations, the model declarations would look like this:

```crystal
class Author < Jennifer::Model::Base
  mapping(
    id: Primary64,
  )
end

class Book < Jennifer::Model::Base
  mapping(
    id: Primary64,
    author_id: Int64?,
    title: String
  )
end
```

Now, suppose we wanted to add a new book for an existing author. We'd need to do something like this:

```crystal
author = Author.first!
book = Book.create({author_id: author.id, title: "Kobzar"})
```

Or consider deleting an author, and ensuring that all of its books get deleted as well:

```crystal
books = Book.where(author_id: author.id)
books.each(&.destroy)
author.destroy
```

With relations we can simplify such kind of operations by defining that there is a connection between the two models. Here's the revised code for setting up authors and books:

```crystal
class Author < Jennifer::Model::Base
  mapping(
    id: Primary64,
  )

  has_many :books, Book, dependent: :destroy
end

class Book < Jennifer::Model::Base
  mapping(
    id: Primary64,
    author_id: Int64?,
    title: String
  )

  belongs_to :author, Author
end
```

With this change, creating a new book for a particular author is easier:


```crystal
book = author.add_book({title: "Kobzar"})
```

Deleting an author and all of its books is much easier:

```crystal
author.destroy
```

## Types of Relationships

There are 4 types of relations: `has_many`, `has_and_belongs_to_many`, `belongs_to` and `has_one`.

They take the next list of arguments:

- `name` - relation name
- `klass` - target class
- `request` - additional request (will be used inside of where clause) - optional
- `foreign` - name of foreign key - optional; by default use singularized table name + "_id"
- `primary` - primary field name - optional;  by default it uses default primary field of class.
- other

### `belongs_to`

In database terms, the `belongs_to` association says that this model's table contains a column which represents a reference to another table. This can be used to set up one-to-one or one-to-many relations.

The next methods are automatically generated when you use `belongs_to` relation:

- `#relation` - cache relation object;
- `#relation_reload` - reload relation and returns it;
- `#relation_query` - returns query which is used to get objects of this object relation entities form db.
- `#remove_relation` - removes given object from relation
- `#add_relation` - adds given object to relation or builds it from hash and then adds
- `#relation!` - calls `#relation` with a `nil` assertion

Supports following extra options:

- `dependent` - defines extra callback for cleaning up related data after destroying parent one
- `polymorphic` - passing true indicates that this is a polymorphic association
- `foreign_type` - specifies the column used to store the associated object's type; can be used for a polymorphic relation
- `required` - passing `true` will validate presence of related object; by default it is `false`

#### `dependent`

Allowed values are:

- `none` - will do nothing; default
- `delete` - deletes all related objects
- `destroy` - destroys all related objects
- `restrict_with_exception` - will raise `Jennifer::RecordExists` exception if there is any related object

#### `required`

Besides `true`/`false` values it also accepts same values supported by `message` option of validation macro (read more in [validation](./validation.md) section).

```crystal
class Post < Jennifer::Model::Base
  mapping(
    id: Primary64,
    title: String?,
    user_id: Int64?
  )

  belongs_to :user, User, required: ->(object : Jennifer::Model::Translation, _field : String) do
      record = object.as(Post)
      "Post #{record.title} isn't attached to any user"
    end
end
```

### `has_one`

The `has_one` relation creates a one-to-one match with another model. In database terms, this relationship says that the other class contains the foreign key. If this class contains the foreign key, then you should use `belongs_to` instead.

The next methods are automatically generated when you use `has_one` relation:

- `#relation` - cache relation object;
- `#relation_reload` - reload relation and returns it;
- `#relation_query` - returns query which is used to get objects of this object relation entities form db.
- `#remove_relation` - removes given object from relation
- `#add_relation` - adds given object to relation or builds it from hash and then adds
- `#relation!` - calls `#relation` with a `nil` assertion

Supports following extra options:

- `dependent` - defines extra callback for cleaning up related data after destroying parent one
- `polymorphic` - passing true indicates that this is a polymorphic association
- `foreign_type` - specifies the column used to store the associated object's type; can be used for a polymorphic relation
- `inverse_of` - specifies the name of the `belongs_to` association that is the inverse of this relationship

#### `dependent`

Allowed values are:

- `nullify` - sets foreign key to `null`; default
- `none` - will do nothing
- `delete` - deletes all related objects
- `destroy` - destroys all related objects
- `restrict_with_exception` - will raise `Jennifer::RecordExists` exception if there is any related object

### `has_many`

The `has_many` relationship creates a one-to-many relationship with another model. In database terms, this relationship says that the other class will have a foreign key that refers to instances of this class.

The next methods are automatically generated when you use `has_many` relation:

- `#relation` - cache relationship collection;
- `#relation_reload` - reload relation and returns it;
- `#relation_query` - returns query which is used to get objects of this object relation entities form db.
- `#remove_relation` - removes given object from relation
- `#add_relation` - adds given object to relation or builds it from hash and then adds
- `#relation_reload` - reloads related objects from the DB

Supports following extra options:

- `dependent` - defines extra callback for cleaning up related data after destroying parent one
- `polymorphic` - passing true indicates that this is a polymorphic association
- `foreign_type` - specifies the column used to store the associated object's type; can be used for a polymorphic relation
- `inverse_of` - specifies the name of the `belongs_to` association that is the inverse of this relationship

#### `dependent`

Allowed values are:

- `nullify` - sets foreign key to `null`; default
- `none` - will do nothing
- `delete` - deletes all related objects
- `destroy` - destroys all related objects
- `restrict_with_exception` - will raise `Jennifer::RecordExists` exception if there is any related object

### `has_and_belongs_to_many`

The `has_and_belongs_to_many` association creates a many-to-many relationship with another model. In database terms, this associates two classes via an intermediate join table that includes foreign keys referring to each of the classes.

By given parameters could be specified field names described on the next schema:

```text
| "Model A" |   | "Join Table" (join_table) |       | "Model B"               |
| --------- |   |---------------------------|       |-------------------------|
| primary   |<--| foreign                   |   /-->| "model b primary field" |
                | association_foreign       |--/
```

As you can see primary field of related model can't be specified - defined primary key (in the mapping) will be got.

The next methods are automatically generated when you use `has_many` relation:

- `#relation` - cache relationship collection;
- `#relation_reload` - reload relation and returns it;
- `#relation_query` - returns query which is used to get objects of this object relation entities form db.
- `#remove_relation` - removes given object from relation
- `#add_relation` - adds given object to relation or builds it from hash and then adds
- `#relation_reload` - reloads related objects from the DB

Supports following extra options:

- `join_table` - specifies the name of the join table if the default based on lexical order isn't what you want
- `association_foreign` - specifies the foreign key used for the association on the receiving side of the association

## Inverse of

Active Record provides the :inverse_of option so you can explicitly declare bi-directional associations:

`has_many` and `has_one` relations accepts `inverse_of` option so you can explicitly declare bi-directional associations:

```crystal
class Author < Jennifer::Model::Base
  mapping(id: Primary64)

  has_many :books, Book, dependent: :destroy, inverse_of: :writer
end

class Book < Jennifer::Model::Base
  mapping(
    id: Primary64,
    author_id: Int64?
  )

  belongs_to :writer, Author, foreign: :author_id
end
```

By including the `:inverse_of` option in the `has_many` association declaration, Jennifer will now recognize the bi-directional association:

```crystal
author = Author.first!
book = author.books.first!
author.object_id == book.writer.object_id # => true
```

## Polymorphic Relations

With polymorphic relations, a model can belong to more than one other model, on a single association. For example, you might have a picture model that belongs to either an employee model or a product model. Here's how this could be declared:

```crystal
class Picture < Jennifer::Model::Base
  mapping(
    id: Primary64,
    imageable_type: String?,
    imageable_id: Int64?
  )

  belongs_to :imageable, Union(Employee | Product) polymorphic: true
end

class Employee < Jennifer::Model::Base
  mapping(
    id: Primary64
  )

  has_many :pictures, Picture, polymorphic: true, inverse_of: :imageable
end

class Product < Jennifer::Model::Base
  mapping(
    id: Primary64
  )

  has_many :pictures, Picture, polymorphic: true, inverse_of: :imageable
end
```

You can think of a polymorphic `belongs_to` declaration as setting up an interface that any other model can use. From an instance of the `Employee` model, you can retrieve a collection of pictures: `employee.pictures`.

Similarly, you can retrieve `product.pictures`.

**Important restriction**: Polymorphic `belongs_to` relation can't be loaded dynamically. E.g., based on the previous example:

```crystal
Picture.includes(:imageable) # This is forbidden
```
