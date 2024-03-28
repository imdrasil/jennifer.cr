require "colorize"

module Jennifer::Adapter
  # Colorized logger formatter
  #
  # This formatter has the same structure as `Jennifer::Adapter::DBFormatter` but with colored sections which
  # simplifies reading. You need to require formatter before use: `require "jennifer/adapter/db_colorized_formatter"`.
  #
  # `db: 5.1 ms SELECT COUNT(*) FROM users WHERE users.role = $1  | ["admin"]`
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
  #   source:       Colorize::ColorRGB.new(17, 120, 100),
  #   args:         :yellow,
  #   query_insert: :green,
  #   query_delete: :red,
  #   query_update: Colorize::ColorRGB.new(236, 88, 0),
  #   query_select: :cyan,
  #   query_other:  :magenta,
  # }
  # ```
  struct DBColorizedFormatter < Log::StaticFormatter
    @@colors = {
      source:       Colorize::ColorRGB.new(17, 120, 100).as(Symbol | Colorize::Color),
      args:         :yellow.as(Symbol | Colorize::Color),
      query_insert: :green.as(Symbol | Colorize::Color),
      query_delete: :red.as(Symbol | Colorize::Color),
      query_update: Colorize::ColorRGB.new(236, 88, 0).as(Symbol | Colorize::Color), # persimmon
      query_select: :cyan.as(Symbol | Colorize::Color),
      query_other:  :magenta.as(Symbol | Colorize::Color),
    }

    def self.colors=(value)
      @@colors = value
    end

    def run
      source(after: ": ")
      elapsed_time(after: " ms ")
      query
      query_arguments(before: " | ")
    end

    def source(*, before = nil, after = nil)
      @io << before << @entry.source.colorize(@@colors[:source]) << after
    end

    def elapsed_time(*, before = nil, after = nil)
      @io << before << @entry.data[:time] << after
    end

    def query(*, before = nil, after = nil)
      query = @entry.data[:query].as_s
      @io << before << query.colorize(query_color(query)) << after
    end

    def query_arguments(*, before = nil, after = nil)
      entry_data = @entry.data
      @io << before << entry_data[:args].to_s.colorize(@@colors[:args]) << after if entry_data[:args]?
    end

    def query_color(message)
      if message =~ /^INSERT/
        @@colors[:query_insert]
      elsif message =~ /^UPDATE/
        @@colors[:query_update]
      elsif message =~ /^SELECT/
        @@colors[:query_select]
      elsif message =~ /^DELETE/
        @@colors[:query_delete]
      else
        @@colors[:query_other]
      end
    end
  end
end
