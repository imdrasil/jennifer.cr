# Internationalization

To provided different languages support [i18n](https://github.com/TechMagister/i18n.cr) lib is used. For feather reading please check it's README.

## Translation for Jennifer Models

You can use the `Jennifer::Model::Base.human` and `Jennifer::Model::Base.human_attribute_name(attribute)` to get translation for your model and attribute names. If there is no defined translation - it will be guessed by `Inflector.humanize`.

### Model translation lookup

Firstly path `jennifer.models.your_model_name` will be checked. If there is no such - all ancestors will be iterated: `jennifer.models.parent_model` and feather. Otherwise - `Inflector.humanize(i18n_key)` will be invoked.

Also model name could be pluralized passing `count` as argument.

```crystal
User.human(count: 2) # Customers
```

### Attribute translation lookup

`.human_attribute_name` will use following lookup:

- `jennifer.attributes.[model_name].attributes.attribute_name`
- `jennifer.attributes.[parent_model_name].attributes.attribute_name` and so on for all ancestors
- `jennifer.attributes.attribute_name`

### Error message translation

Error messages of predefined validation helper macros are generated using `Jennifer::Model::Errors#generate_message` method and is retrieved from local files. Lets take a look how it will search `blank` error message:

- `jennifer.errors.[model_name].attributes.[attribute_name].blank`
- `jennifer.errors.[model_name].[attribute_name].blank`
- `jennifer.errors.[ancestor_model_name].attributes.[attribute_name].blank`
- `jennifer.errors.[ancestor_model_name].[attribute_name].blank` (this and previous one will be repeated for all ancestors)
- `jennifer.errors.[attribute_name].blank`
- `jennifer.errors.messages.blank`

Based on this you can specify specific message for any error.

#### Interpolation

Some message accepts arguments to pe inserted into translation. Here is full list of them:

| Validation | Message | Interpolation |
| --- | --- | --- |
| confirmation | :confirmation | attribute |
| length | :too_long | count |
| length | :too_short | count |
| length | :wrong_length | count |
| numericality | :greater_than | value |
| numericality | :greater_than_or_equal_to | value |
| numericality | :equal_to | value |
| numericality | :less_than | value |
| numericality | :less_than_or_equal_to | value |
| numericality | :other_than | value |
