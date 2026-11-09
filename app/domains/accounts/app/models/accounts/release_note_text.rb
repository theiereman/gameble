module Accounts
  # A note's body read as plain lines: "## " opens a section, "- " is one of its items, any other line is a paragraph.
  module ReleaseNoteText
    Paragraph = Data.define(:text)
    Section = Data.define(:title, :items)

    def self.blocks(body)
      body.to_s.lines.map(&:strip).reject(&:empty?).each_with_object([]) do |line, blocks|
        if (title = line.delete_prefix!("## "))
          blocks << Section.new(title: title.strip, items: [])
        elsif line.start_with?("- ")
          item = line.delete_prefix("- ").strip
          blocks << Section.new(title: nil, items: []) unless blocks.last.is_a?(Section)
          blocks.last.items << item
        else
          blocks << Paragraph.new(text: line)
        end
      end
    end
  end
end
