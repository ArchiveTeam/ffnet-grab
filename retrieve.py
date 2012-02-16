#!/usr/bin/env python

from BeautifulSoup import BeautifulSoup
import httplib
import math
import os
import re
import string
import subprocess
import sys

def urls_for(profile):
    """
    1. Find the stories written by the profile's author.
    2. For each story:
        a. Generate URLs to each page in the story.
        b. Generate review URLs.
    """
   
    conn = httplib.HTTPConnection('www.fanfiction.net')
    conn.request("GET", profile)
    response = conn.getresponse()
    doc = BeautifulSoup(response.read())

    # The author's stories.
    story_tab = doc.find(id="st")
    links = story_tab.findAllNext('a')

    # We're only interested in links whose href =~ /s/\d+.
    sl_re = re.compile(r'/s/(\d+)')

    stories = []
    for l in links:
        result = sl_re.match(l['href'])
        if result:
            stories.append((l, result.group(1)))

    chapters = dict()
    reviews = dict()
    chapter_re = re.compile(r'Chapters:[^\d]*(\d+)')
    reviews_re = re.compile(r'Reviews:[^\d]*(\d+)')
    paths = [profile]

    for (l, key) in stories:
        if key in chapters:
            pass
        else:
            z_indent = l.findNextSibling('div')
            info_text = z_indent.findNext('div').string

            # Each story link is followed by a bit of gray text with story metadata.
            # The relevant bit of metadata (at this stage) is the number of chapters;
            # knowing that, we can build story chapter URLs without fetching any more
            # pages.
            result = chapter_re.search(info_text)
            chapter_count = int(result.group(1))
            chapters[key] = (l, chapter_count)

            # OK, we've gotten the chapters.  Now we need to figure out how
            # many pages of reviews this story has.
            #
            # Currently, fanfiction.net displays 15 reviews per page, so we calculate
            # ceil(review_count / 15).
            result = reviews_re.search(info_text)

            if result:
                review_count = int(math.ceil(float(result.group(1)) / 15))
                reviews[key] = review_count

    # We've now got what we need to build URLs for this profile.
    # We build the canonical URLs to maintain referential integrity of the
    # chapter selection box.
    for key in chapters:
        l, count = chapters[key]

        canonical_path = l['href']
        result = re.search(r'/s/\d+/\d+(/.*)$', canonical_path)

        for i in range(count):
            paths.append('/s/' + key + '/' + str(i + 1) + result.group(1))

        if key in reviews:
            for i in range(reviews[key]):
                paths.append('/r/' + key + '/0/' + str(i + 1))

    return ["http://www.fanfiction.net%s" % path for path in paths]

# ------------------------------------------------------------------------------ 

if len(sys.argv) < 2:
    print "Usage: %s YOUR_USERNAME" % sys.argv[0]
    sys.exit(1)

username = sys.argv[1]
tracker = "fujoshi.at.ninjawedding.org"
conn = httplib.HTTPConnection(tracker)
# Get a profile.
# 
# POST /request => [200, item] | [404, nothing]
print "Requesting work item."
conn.request("POST", "/request", '{"downloader":"%s"}' % username)
response = conn.getresponse()

if response.status == 404:
    print "Tracker returned 404; assuming todo queue is empty.  Exiting."
    sys.exit

# If we got a profile, fetch it.
if response.status == 200:
    profile = response.read()
    print "- Received profile %s." % profile
    print "- Generating URLs for profile %s." % profile
    urls = urls_for(profile)
    print "  - %d URLs to fetch." % len(urls)

    print "- Building directory structure for %s." % profile
    result = re.match(r'/u/(\d+)/.+$', profile)
    profile_id = result.group(1)
    directory = 'data/%s/%s/%s/%s' % (profile_id[0], profile_id[0:2], profile_id[0:3], profile_id)
    print '  - %s' % directory
    os.makedirs(directory, 0755)

    print '- Writing URLs for %s.' % profile

    with open('%s/%s.txt' % (directory, profile_id), 'w') as url_file:
        for url in urls:
            url_file.write(url + '\n')

    print '- Retrieving %s.' % profile
    subprocess.check_call('./get_one.sh %s %s %s' % (profile_id, directory, username), shell=True)

# vim:ts=4:sw=4:et
