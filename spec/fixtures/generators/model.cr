class Article < Jennifer::Model::Base
  with_timestamps

  mapping(
    id: Primary64,
    title: String,
    text: String?,
    created_at: Time?,
    updated_at: Time?,
  )
end
