require 'connection_pool'
require 'girl_friday'
require 'mechanize'
require 'redis'
require 'thread'

require File.expand_path('../support', __FILE__)

ROOTS = %w(
  /anime/
  /book/
  /cartoon/
  /comic/
  /game/
  /misc/
  /movie/
  /play/
  /tv/
  /crossovers/anime/
  /crossovers/book/
  /crossovers/cartoon/
  /crossovers/comic/
  /crossovers/game/
  /crossovers/misc/
  /crossovers/movie/
  /crossovers/play/
  /crossovers/tv/
)

crawler_pool = ConnectionPool.new(:size => 8) do
  Mechanize.new.tap do |m|
    m.max_history = 0
  end
end

redis_pool = ConnectionPool.new(:size => 12) { Redis.new }

grab = GirlFriday::WorkQueue.new(:grab, :size => 8) do |story_link|
  redis_pool.with_connection do |redis|
    save_story(story_link, redis)
  end
end

discovery = GirlFriday::WorkQueue.new(:discovery, :size => 8) do |root|
  begin
    stories, categories = crawler_pool.with_connection do |agent|
      redis_pool.with_connection do |redis|
        stories_and_categories_of(root, agent, redis)
      end
    end
  rescue Exception => e
    $LOG.error("Exception #{e.class} (#{e.message}) raised while scraping #{root}; requeuing.")
    discovery << root
  end

  categories.each { |c| discovery << c }
  stories.each do |s|
    grab << s
  end
end

trap 'INT' do
  $LOG.info("SIGINT received, terminating")

  grab.shutdown
  discovery.shutdown

  exit 1
end

ROOTS.each { |r| discovery << r }

loop { sleep 5 }
