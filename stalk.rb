require 'connection_pool'
require 'fileutils'
require 'girl_friday'
require 'redis'

require File.expand_path('../constants', __FILE__)
require File.expand_path('../path_helpers', __FILE__)

include FileUtils
include PathHelpers

WORKERS = 4
VERSION = `git log --oneline #{$0} | head -n 1 | awk '{print $1}'`.chomp

rp = ConnectionPool.new(:size => WORKERS) { Redis.new }

download_queue = GirlFriday::WorkQueue.new(:download_profiles, :size => 2) do |profile_url|
  LOG.info "Retrieving #{profile_url}."

  pid = profile_id(profile_url)
  profile_dir = profile_dir_for(pid)
  log_file = profile_log_file(pid)
  warc_file = profile_warc_file(pid)

  cmd = [
    WGET_WARC,
    "-U " + E[USER_AGENT],
    "-e robots=off",
    "-nv",
    "-o " + E[log_file],
    "--directory-prefix=" + E[temp_dir_for("profile_#{pid}")],
    "--warc-file=" + E[warc_file],
    "--warc-header=" + E["operator: Archive Team"],
    "--warc-header=" + E["fanfiction-net-script-version: #{VERSION}"],
    "--warc-header=" + E["fanfiction-net-downloader: #{ENV['USERNAME']}"],
    "--no-remove-listing",
    "--no-timestamping",
    "--trust-server-names",
    "--page-requisites",
    "--span-hosts",
    "-X " + E["/static/styles"],
    "-X " + E["/static/scripts"],
    profile_url
  ].join(' ')

  LOG.debug "Running #{cmd}"

  mkdir_p profile_dir

  `#{cmd}`

  LOG.info "Finished #{profile_url}."

  rp.with_connection do |r|
    r.zrem STORES[:profiles_working], profile_url
    r.sadd STORES[:profiles_done], profile_url
  end
end

loop do
  LOG.info "Checking for profiles."

  rp.with_connection do |r|
    loop do
      profile_url = r.spop STORES[:profiles_todo]

      if profile_url
        r.zadd STORES[:profiles_working], Time.now.to_i, profile_url

        download_queue << profile_url
      else
        break
      end
    end
  end

  sleep 10
end
