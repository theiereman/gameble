module MarkdownNegotiation
  extend ActiveSupport::Concern

  MARKDOWN_TYPE = "text/markdown".freeze
  HTML_TYPES = %w[text/html application/xhtml+xml].freeze
  WILDCARD_TYPES = %w[text/* */*].freeze

  class_methods do
    def negotiates_markdown(**filter)
      before_action :vary_on_accept, **filter
    end
  end

  private
    def vary_on_accept
      varied = response.headers["Vary"].to_s.split(",").map(&:strip).compact_blank
      response.headers["Vary"] = (varied | [ "Accept" ]).join(", ")
    end

    # Markdown wins only when the client names it and ranks it above HTML and at least as high as any wildcard.
    def markdown_requested?
      ranks = accepted_ranks
      markdown = ranks.fetch(MARKDOWN_TYPE, 0.0)
      markdown.positive? && markdown > best_rank(ranks, HTML_TYPES) && markdown >= best_rank(ranks, WILDCARD_TYPES)
    end

    def best_rank(ranks, types)
      ranks.values_at(*types).compact.max || 0.0
    end

    def accepted_ranks
      request.headers["Accept"].to_s.split(",").each_with_object({}) do |entry, ranks|
        type, *parameters = entry.split(";").map(&:strip)
        next if type.blank?

        quality = parameters.filter_map { it[/\Aq=(\d(?:\.\d+)?)\z/i, 1] }.first
        ranks[type.downcase] = [ ranks[type.downcase] || 0.0, (quality || 1).to_f ].max
      end
    end

    def render_markdown(template = action_name)
      html = render_to_string(template, formats: :html, layout: false)
      send_markdown(MarkdownPage.from_html(html, base_url: request.base_url))
    end

    def send_markdown(body)
      render plain: body, content_type: "#{MARKDOWN_TYPE}; charset=utf-8"
    end
end
