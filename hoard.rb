require 'connection_pool'
require 'girl_friday'
require 'mechanize'
require 'redis'

require File.expand_path('../url_helpers', __FILE__)

include UrlHelpers

WORKERS = 4

rp = ConnectionPool.new(:size => WORKERS * 2) { Redis.new }
mp = ConnectionPool.new(:size => WORKERS) do
  Mechanize.new do |m|
    m.user_agent = 'Linux Firefox'
    m.max_history = 0
  end
end

common_config = {
  :store => GirlFriday::Store::Redis,
  :store_config => {
    :pool => rp
  },
  :size => WORKERS
}

GirlFriday::WorkQueue.new(:hoard, common_config) do |sid|
  mp.with_connection do |agent|
    urls = urls_for(sid, agent)

    story_and_reviews = urls[:story] + urls[:reviews]

    # and here we should build a wget-warc line
    puts story_and_reviews.inspect
  end
end
