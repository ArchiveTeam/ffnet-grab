require 'escape'
require 'logger'

DOWNLOAD_TO = File.expand_path('../data', __FILE__)
E           = lambda { |str| Escape.shell_single_word(str) }
LOG         = Logger.new($stderr)
TMPFS       = File.expand_path('../tmpfs', __FILE__)
USER_AGENT  = 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_6; en-us) AppleWebKit/528.16 (KHTML, like Gecko) Stainless/0.5.3 Safari/525.20.1'
WGET_WARC   = File.expand_path('../wget-warc', __FILE__)

STORES = {
  :profiles_todo => 'ffnet_profiles_todo',
  :profiles_done => 'ffnet_profiles_done',
  :profiles_working => 'ffnet_profiles_working',
  :stories_todo => 'ffnet_stories_todo',
  :stories_working => 'ffnet_stories_working',
  :stories_done => 'ffnet_stories_done',
  :stories_known => 'stories'
}
