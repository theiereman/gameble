class LlmsController < ApplicationController
  include PublicRead

  def show
    authorize :page, :show?
    return head :not_found unless Rails.configuration.x.search_indexing

    expires_in 1.hour, public: true
    render plain: document
  end

  private
    def document
      I18n.with_locale(:en) do
        <<~MARKDOWN
          # #{t("layouts.application.application_name")}

          > #{t("layouts.application.description")}

          Every page exists in English (`/en`) and French (`/fr`). Pages also answer `Accept: text/markdown` with a Markdown version.

          ## Pages

          #{pages.join("\n")}

          ## Optional

          - [Sitemap](#{helpers.public_url_for("/sitemap.xml")}): every public page in both languages
        MARKDOWN
      end
    end

    def pages
      [
        entry(t("landings.show.title"), helpers.public_url_for(home_path(locale: :en)), t("landings.show.description")),
        entry(t("pages.how_it_works.title"), helpers.public_url_for(how_it_works_path(locale: :en))),
        entry(t("roadmaps.show.title"), helpers.public_url_for(roadmap_path(locale: :en)), t("roadmaps.show.description")),
        entry(t("pages.credits.title"), helpers.public_url_for(credits_path(locale: :en))),
        entry(t("pages.legal.title"), helpers.public_url_for(legal_path(locale: :en)))
      ]
    end

    def entry(title, url, description = nil)
      [ "- [#{title}](#{url})", description ].compact.join(": ")
    end
end
