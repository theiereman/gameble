require "nokogiri"

module Steam
  # Steam's store text as plain text (epic 2 R4): an HTML fragment parsed with
  # Nokogiri's HTML5 parser, line breaks and the ends of blocks turned into
  # spaces, entities decoded, whitespace squished.
  #
  #   Steam::PlainText.call("<b>Fun</b> &amp; games<br>for all")
  #   # => "Fun & games for all"
  module PlainText
    BLOCKS = %w[p div li ul ol h1 h2 h3 h4 h5 h6 tr td th table blockquote section article header footer pre].freeze

    def self.call(html)
      return "" if html.blank?

      fragment = Nokogiri::HTML5.fragment(html.to_s)
      fragment.css("br").each { |node| node.replace(" ") }
      fragment.css(BLOCKS.join(",")).each { |node| node.add_next_sibling(Nokogiri::XML::Text.new(" ", fragment.document)) }
      fragment.text.squish
    end
  end
end
