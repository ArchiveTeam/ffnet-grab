require 'connection_pool'
require 'girl_friday'
require 'redis'

# Watches for new profile URLs and fetches them.  Profiles are bunched in
# groups of 100000.
