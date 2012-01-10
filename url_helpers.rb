require 'logger'

module UrlHelpers
  BASE_URL = "http://www.fanfiction.net"
  LOG = Logger.new($stderr)

  U = lambda { |sid, rest| "#{BASE_URL}/s/#{sid}#{rest}" }
  R = lambda { |sid, rest| "#{BASE_URL}/r/#{sid}#{rest}" }

  def urls_for(sid, agent)
    story_page = agent.get(U[sid, ''])

    { :story => story_urls_in(story_page),
      :reviews => review_urls_for(story_page, sid, agent),
      :profile => profile_urls_in(story_page)
    }.tap do |h|
      sl = h[:story].length
      rl = h[:reviews].length

      LOG.info("Story #{sid}: #{sl} chapters, #{rl} pages of reviews")
    end
  end

  def story_urls_in(page)
    # The canonical URI always includes a chapter number,
    # even for stories that have only one chapter.
    story_canonical_uri = page.canonical_uri.to_s

    chapter_box = (page/'select[name="chapter"]').first

    if chapter_box
      chapters = chapter_box/'option'

      chapters.map do |chapter|
        number = chapter.attribute('value').text
        comp = story_canonical_uri.match %r{/s/(\d+)/\d+/(.+)$}
        chapter_uri = U[comp[1], "/#{number}/#{comp[2]}"]
      end
    else
      [story_canonical_uri]
    end
  end

  def review_urls_for(story_page, sid, agent)
    if story_page.links.map(&:href).any? { |h| h =~ %r{/r/#{sid}} }
      review_page = agent.get(R[sid, '/'])
      highest_page = review_page.links.map(&:href).map { |h| h =~ %r{/r/#{sid}/0/(\d+)}; $1 }.map(&:to_i).max

      if highest_page > 1
        1.upto(highest_page).map do |n|
          R[sid, "/0/#{n}"]
        end
      else
        [R[sid, '/']]
      end
    else
      # no reviews, no URLs to generate
      []
    end
  end

  def profile_urls_in(page)
    profile_link = page.links.map(&:href).detect { |h| h =~ %r{/u/\d+} }

    [profile_link]
  end
end
