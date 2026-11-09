require "faraday"

module Accounts
  # Reads a release's commits from the public repository: from the release before it to its own tag,
  # else to its newest candidate, else to develop when no candidate is cut yet.
  class GithubReleaseChanges
    BASE_URL = "https://api.github.com".freeze
    REPOSITORY = "theiereman/gameble".freeze
    TAG_PAGES = 5
    PER_PAGE = 100

    class_attribute :connection_adapter, default: [ Faraday.default_adapter ]

    def self.for(version)
      new.for(version)
    end

    def for(version)
      tags = tag_names
      since = tags.filter_map { ReleaseVersion.parse(it) }.select { it < version }.max
      return unless since

      head = head_for(version, tags)
      commits = get("/repos/#{REPOSITORY}/compare/#{since}...#{head}").fetch("commits")
      ReleaseChanges.new(since: since.to_s, head:, subjects: commits.map { it.dig("commit", "message").to_s.lines.first.to_s })
    rescue Faraday::Error, KeyError, TypeError, NoMethodError
      nil
    end

    private

    def tag_names
      (1..TAG_PAGES).each_with_object([]) do |page, names|
        batch = get("/repos/#{REPOSITORY}/tags", per_page: PER_PAGE, page:).map { it.fetch("name") }
        names.concat(batch)
        break names if batch.size < PER_PAGE
      end
    end

    def head_for(version, tags)
      return version.to_s if tags.include?(version.to_s)

      candidate = /\A#{Regexp.escape(version.to_s)}-rc\.(\d+)\z/
      tags.filter_map { (match = candidate.match(it)) && [ match[1].to_i, it ] }.max&.last || "develop"
    end

    def get(path, params = {})
      http.get(path, params).body
    end

    def http
      @http ||= Faraday.new(BASE_URL, headers: { "Accept" => "application/vnd.github+json", "User-Agent" => "gameble" },
        request: { open_timeout: 3, timeout: 5 }) do |builder|
        builder.response :raise_error
        builder.response :json
        builder.adapter(*connection_adapter)
      end
    end
  end
end
