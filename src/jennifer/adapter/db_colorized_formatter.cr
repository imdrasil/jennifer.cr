require "colorize"

module Jennifer::Adapter
  # Colorized logger formatter
  #
  # This formatter has the same structure as `Jennifer::Adapter::DBFormatter` but with colored sections which
  # simplifies reading. You need to require formatter before use: `require "jennifer/adapter/db_colorized_formatter"`.
  #
  # `2020-10-11T12:13:14.424770Z  DEBUG - db: 500.736 μs SELECT COUNT(*) FROM users WHERE users.role = $1  | ["admin"]`
  #
  # A log entry has 3 colored sections:
  # - `db` - namespace
  # - `SELECT COUNT(*) FROM users WHERE users.role = $1` - query
  # - `["admin"]` - query arguments
  #
  # To customize used colors change `colors` with desired colors:
  #
  # ```
  # Jennifer::Adapter::DBColorizedFormatter.colors = {
  #   namespace: :green,
  #   query:     :blue,
  #   args:      :yellow,
  # }
  # ```
  struct DBColorizedFormatter < Log::StaticFormatter
    @@colors : NamedTuple(
      namespace: Symbol | Colorize::Color,
      query: Symbol | Colorize::Color,
      args: Symbol | Colorize::Color) = {
      namespace: :green,
      query:     :blue,
      args:      :yellow,
    }

    def self.colors=(value)
      @@colors = value
    end

    def run
      entry_data = @entry.data
      timestamp
      severity
      @io <<
        " - " <<
        @entry.source.colorize(@@colors[:namespace]) <<
        ": " <<
        entry_data[:time] <<
        " μs " <<
        entry_data[:query].colorize(@@colors[:query])
      @io << " | " << entry_data[:args].colorize(@@colors[:args]) if entry_data[:args]?
    end
  end
end
