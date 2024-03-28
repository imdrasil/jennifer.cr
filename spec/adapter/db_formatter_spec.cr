require "../spec_helper"

describe Jennifer::Adapter::DBFormatter do
  described_class = Jennifer::Adapter::DBFormatter

  describe "#run" do
    it "formats an entry" do
      metadata = {query: "SELECT COUNT(*) FROM users WHERE id > ?", args: "[1]", time: 582.1}
      entry = Log::Entry.new("db", :info, "ignored message", Log::Metadata.build(metadata), nil)
      io = IO::Memory.new
      described_class.format(entry, io)
      io.to_s
        .should match(/^[\d\-.:TZ]+\s* INFO - db: #{Regex.escape(metadata[:time].to_s)} ms #{Regex.escape(metadata[:query])} \| #{Regex.escape(metadata[:args])}$/)
    end
  end
end
