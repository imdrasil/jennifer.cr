class Article < Jennifer::Model::Base
  with_timestamps

  mapping(
    id: Primary64,
    title: String,
    text: String?,
    author_id: Int64?,
    created_at: Time?,
    updated_at: Time?,
  )

  belongs_to :author, Author
end
