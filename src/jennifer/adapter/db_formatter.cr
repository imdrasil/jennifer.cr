module Jennifer::Adapter
  # Default log formatter
  #
  # `2020-10-11T12:13:14.424770Z  DEBUG - db: 5.7 ms SELECT COUNT(*) FROM users WHERE users.role = $1  | ["admin"]`
  struct DBFormatter < Log::StaticFormatter
    def run
      entry_data = @entry.data
      timestamp
      severity
      @io << " - "
      source(after: ": ")
      @io << entry_data[:time] << " ms " << entry_data[:query]
      @io << " | " << entry_data[:args] if entry_data[:args]?
    end
  end
end
