class MarkdownPage
  LEFT_OUT = %w[script style template svg img picture button form input select textarea nav noscript].freeze
  HEADINGS = %w[h1 h2 h3 h4 h5 h6].freeze
  LISTS = %w[ul ol].freeze
  INLINE_TAGS = %w[a b strong i em code span time small abbr mark label sup sub br].freeze

  def self.from_html(html, base_url: "")
    new(Nokogiri::HTML5.fragment(html), base_url:).to_s
  end

  def initialize(fragment, base_url:)
    @fragment = fragment
    @base_url = base_url
  end

  def to_s
    "#{flow(@fragment, in_list: false).join("\n\n")}\n"
  end

  private
    def flow(parent, in_list:)
      blocks = []
      run = []
      parent.children.each do |node|
        next if left_out?(node)

        if inline?(node)
          run << node
        else
          blocks << paragraph(run)
          run = []
          blocks.concat(block(node, in_list:))
        end
      end
      blocks << paragraph(run)
      blocks.compact_blank
    end

    def paragraph(nodes)
      nodes.map { inline_node(it) }.join.squish
    end

    def block(node, in_list:)
      case node.name
      when *HEADINGS then [ heading(node, in_list) ]
      when "p" then [ inline(node) ]
      when *LISTS then [ list(node) ]
      when "dl" then [ definitions(node) ]
      when "table" then [ table(node) ]
      else flow(node, in_list:)
      end
    end

    def heading(node, in_list)
      text = inline(node)
      in_list ? "**#{text}**" : "#{"#" * node.name[1].to_i} #{text}"
    end

    def list(node)
      items = node.element_children.select { it.name == "li" && !left_out?(it) }
      items.each_with_index.map do |item, index|
        marker = node.name == "ol" ? "#{index + 1}." : "-"
        first, *rest = flow(item, in_list: true).join("\n").lines(chomp: true)
        [ "#{marker} #{first}", *rest.map { "#{" " * (marker.length + 1)}#{it}" } ].join("\n")
      end.join("\n")
    end

    def definitions(node)
      node.css("dt").reject { left_out?(it) }.filter_map do |term|
        description = term.at_xpath("following-sibling::dd[1]")
        "- **#{inline(term)}**: #{inline(description)}" if description
      end.join("\n")
    end

    def table(node)
      rows = node.css("tr").map { |row| row.css("th, td").map { inline(it).gsub("|", "\\|") } }
      return "" if rows.empty?

      header, *body = rows
      lines = [ row_line(header), row_line(header.map { "---" }), *body.map { row_line(it) } ]
      [ inline(node.at_css("caption")), lines.join("\n") ].compact_blank.join("\n\n")
    end

    def row_line(cells)
      "| #{cells.join(" | ")} |"
    end

    def inline(node)
      node ? paragraph(node.children) : ""
    end

    def inline_node(node)
      return node.text.gsub(/\s+/, " ") if node.text?
      return "" if left_out?(node)

      text = node.children.map { inline_node(it) }.join
      case node.name
      when "a" then link(node, text)
      when "b", "strong" then emphasis(text, "**")
      when "i", "em" then emphasis(text, "*")
      when "code" then "`#{text}`"
      when "br" then " "
      when "span" then " #{text} "
      else text
      end
    end

    def emphasis(text, mark)
      text.strip.empty? ? text : "#{mark}#{text.strip}#{mark}"
    end

    def link(node, text)
      href = node["href"].to_s
      return text if href.blank? || text.strip.empty?

      href = "#{@base_url}#{href}" if href.start_with?("/")
      "[#{text.strip}](#{href})"
    end

    def inline?(node)
      node.text? || node.name.in?(INLINE_TAGS)
    end

    def left_out?(node)
      return false if node.text?
      return true unless node.element?

      node.name.in?(LEFT_OUT) || node["aria-hidden"] == "true" || node.key?("hidden")
    end
end
