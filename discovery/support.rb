require 'logger'

$LOG = Logger.new($stderr)

WRAP = lambda { |p| "http://www.fanfiction.net#{p}" }

def within_cache_threshold?(root, redis)
  redis.exists "#{root}_cache_control"
end

def stories_and_categories_of(root, agent, redis)
  if within_cache_threshold?(root, redis)
    stories = redis.smembers "#{root}_stories"
    categories = redis.smembers "#{root}_categories"

    $LOG.info("Using cached result for #{root}: #{stories.length} stories, #{categories.length} categories")

    return [stories, categories]
  end

  last_seen = redis.hget 'last_modified', root

  page = if last_seen
           agent.get WRAP[root], {}, nil, {'If-Modified-Since' => last_seen}
         else
           agent.get WRAP[root]
         end

  if page.code.to_i == 304
    stories = redis.smembers "#{root}_stories"
    categories = redis.smembers "#{root}_categories"

    $LOG.info("Using cached result for #{root}: #{stories.length} stories, #{categories.length} categories")

    return [stories, categories]
  elsif page.code.to_i == 200
    # Category links show up under #list_output,
    # story links under #myform.
    links = (page/'#list_output a') + (page/'#myform a')
    hrefs = links.map do |l|
      if l.attribute('href').nil?
        $LOG.warn("Found link without href on #{root}: #{l.inspect}; ignoring that link.")
        nil
      else
        l.attribute('href').text
      end
    end.compact

    stories, categories = hrefs.partition { |h| h =~ %r{/s/.+} }

    # Remove profile and review links.
    categories.reject! do |c|
      c =~ %r{/r/.+} or c =~ %r{/u/.+}
    end

    # Filter chapter designations out of story links.
    stories.map! do |s|
      s =~ %r{/s/(\d+)}
      $1
    end

    # Store response metadata.
    redis.multi do
      redis.hset 'last_modified', root, page.response['last-modified']

      redis.del "#{root}_stories"
      redis.del "#{root}_categories"
    
      stories.each do |s|
        redis.sadd "#{root}_stories", s
      end

      categories.each do |c|
        redis.sadd "#{root}_categories", c
      end

      # TODO: actually read the Cache-Control header
      redis.set "#{root}_cache_control", "s"
      redis.expire "#{root}_cache_control", 7200
    end

    [stories, categories].tap do |s, c|
      $LOG.info("Found #{c.length} categories, #{s.length} stories from #{root}")

      # wait a bit to be less of an ass
      sleep rand(5)
    end
  else
    $LOG.warn("GET #{root} returned status #{page.code}; returning empty sets for now.")
    return [[], []]
  end
end

def save_story(story_link, redis)
  redis.sadd 'stories', story_link
end
