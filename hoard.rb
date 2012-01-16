require 'connection_pool'
require 'fileutils'
require 'girl_friday'
require 'mechanize'
require 'redis'

require File.expand_path('../constants', __FILE__)
require File.expand_path('../path_helpers', __FILE__)
require File.expand_path('../url_helpers', __FILE__)

include FileUtils
include PathHelpers
include UrlHelpers

WORKERS = 4
VERSION = `git log --oneline #{$0} | head -n 1 | awk '{print $1}'`.chomp

abort "USERNAME must be set" unless ENV['USERNAME']

rp = ConnectionPool.new(:size => WORKERS) { Redis.new }
mp = ConnectionPool.new(:size => WORKERS) do
  Mechanize.new do |m|
    m.user_agent = USER_AGENT
    m.max_history = 0
  end
end

download_queue = GirlFriday::WorkQueue.new(:download_stories, :size => 2) do |sid, urls|
  story_and_reviews = urls[:story] + urls[:reviews]

  userdir = story_dir_for(sid)
  log_file = story_log_file(sid)
  warc_file = story_warc_file(sid)
  url_file = story_url_file(sid)

  cmd = [
    WGET_WARC,
    "-U " + E[USER_AGENT],
    "-e robots=off",
    "-nv",
    "-o " + E[log_file],
    "--directory-prefix=" + E[temp_dir_for("story_#{sid}")],
    "--warc-file=" + E[warc_file],
    "--warc-header=" + E["operator: Archive Team"],
    "--warc-header=" + E["fanfiction-net-script-version: #{VERSION}"],
    "--warc-header=" + E["fanfiction-net-downloader: #{ENV['USERNAME']}"],
    "--no-remove-listing",
    "--no-timestamping",
    "--trust-server-names",
    "--page-requisites",
    "--span-hosts",

    # b.fanfiction.net is broken: it sends gzipped responses to clients that
    # don't claim to support gzip encoding.  Like wget.
    #
    # To work around this, we'll fetch and decompress the CSS and Javascript
    # separately.
    "-X " + E["/static/styles"],
    "-X " + E["/static/scripts"],

    "-i " + E[url_file]
  ].join(' ')

  LOG.debug "Running #{cmd}"

  mkdir_p userdir

  File.open(url_file, 'w') do |f|
    story_and_reviews.each { |url| f.puts url }
  end

  `#{cmd}`

  rp.with_connection do |redis|
    redis.zrem STORES[:stories_working], sid
    redis.sadd STORES[:stories_done], sid
  end

  LOG.info "Finished #{sid}."
end

discovery_queue = GirlFriday::WorkQueue.new(:discover_urls, :size => 4) do |sid|
  urls = mp.with_connection { |agent| urls_for(sid, agent) }

  download_queue << [sid, urls]

  profile_urls = urls[:profile]

  rp.with_connection do |redis|
    profile_urls.each do |url|
      redis.multi do
        unless redis.sismember STORES[:profiles_done], url
          redis.sadd STORES[:profiles_todo], url
        end
      end
    end
  end
end

LOG.info "Populating todo queue."

rp.with_connection do |redis|
  rp.sdiffstore STORES[:stories_todo], STORES[:stories_known], STORES[:stories_done]

  size = rp.scard STORES[:stories_todo]
  LOG.info "Todo queue populated with #{size} story IDs."
end

loop { sleep 30 }
