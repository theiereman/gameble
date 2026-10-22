xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9", "xmlns:xhtml": "http://www.w3.org/1999/xhtml" do
  @pages.each do |alternates|
    alternates.each_value do |location|
      xml.url do
        xml.loc location
        alternates.each { |locale, href| xml.tag!("xhtml:link", rel: "alternate", hreflang: locale, href:) }
      end
    end
  end
end
