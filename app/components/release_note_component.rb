class ReleaseNoteComponent < ViewComponent::Base
  def self.of(note, locale: I18n.locale, title_id: nil)
    new(title: note.title(locale), body: note.body(locale), locale:, title_id:)
  end

  def initialize(title:, body:, locale:, title_id: nil)
    @title = title
    @blocks = Accounts::ReleaseNoteText.blocks(body)
    @locale = locale.to_s
    @title_id = title_id
  end

  def call
    tag.div(class: "release-note", lang: @locale) do
      safe_join([ tag.p(t("release_notes.prompt", locale: @locale), class: "release-note__prompt", aria: { hidden: true }),
        tag.h2(@title, id: @title_id, class: "release-note__title"), *@blocks.map { block(it) } ])
    end
  end

  private
    def block(block)
      case block
      when Accounts::ReleaseNoteText::Paragraph then tag.p(block.text, class: "release-note__text")
      when Accounts::ReleaseNoteText::Section then section(block)
      end
    end

    def section(section)
      tag.section(class: "release-note__section") do
        safe_join([ (tag.h3(section.title, class: "release-note__section-title") if section.title),
          tag.ul(safe_join(section.items.map { tag.li(it, class: "release-note__item") }), class: "release-note__items") ].compact)
      end
    end
end
