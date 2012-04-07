#!/usr/bin/env python

from BeautifulSoup import BeautifulSoup
import json
import math
import os
import re
import requests
import shutil
import string
import subprocess
import sys
import time

VERSION = '20120402.01'

def urls_for(profile):
    """
    1. Find the stories written by the profile's author.
    2. For each story:
        a. Generate URLs to each page in the story.
        b. Generate review URLs.
    """

    response = requests.get("http://www.fanfiction.net/%s" % profile)

    assert response.status_code == 200

    doc = BeautifulSoup(response.text)

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
            # The story links to /r/\d+/, which is technically the same thing as
            # /r/\d+/0/1/, but we'll include the root anyway for e.g. wayback.
            paths.append('/r/' + key + '/')

            for i in range(reviews[key]):
                paths.append('/r/' + key + '/0/' + str(i + 1) + '/')

    return ["http://www.fanfiction.net%s" % path for path in paths]

def archive(profile):
    print "- Downloading profile %s." % profile
    print "- Generating URLs for profile %s." % profile
    urls = urls_for(profile)
    print "  - %d URLs to fetch." % len(urls)

    print "- Building directory structure for %s." % profile
    result = re.match(r'/u/(\d+)/(.+)$', profile)
    profile_id = result.group(1)
    profile_name = result.group(2)

    directory = 'data/%s/%s/%s/%s%s' % (username, profile_id[0:1], profile_id[0:2], profile_id[0:3], profile)
    incomplete = directory + '/.incomplete'

    print '  - %s' % directory

    print "- Ensuring %s is empty." % directory
    shutil.rmtree(directory, ignore_errors=True)
    os.makedirs(directory, 0755)

    file(incomplete, 'a')

    print '- Writing URLs for %s.' % profile
    with open('%s/%s.txt' % (directory, profile_id), 'w') as url_file:
        for url in urls:
            url_file.write(url + '\n')

    print '- Retrieving %s.' % profile
    subprocess.check_call('./get_one.sh %s %s %s %s' % (profile_id, directory, username, VERSION), shell=True)

    print '- Telling tracker that %s has been downloaded.' % profile
    bytes = os.stat('%s/%s.warc.gz' % (directory, profile_id)).st_size

    data = {'downloader': username,
            'item': profile,
            'bytes': {
                'warcgz': bytes
             },
            'version': VERSION}

    response = requests.post(base_url + "/done", json.dumps(data))

    print '  - %s' % data
    if response.status_code == 200:
        print '- Tracker acknowledged download of %s.' % profile

        os.remove(incomplete)

        print '- Uploading %s to %s.' % (profile, upload_to)
        
        subprocess.check_call('./upload.sh %s %s' % (directory, upload_to), shell=True)

        print '- Telling tracker that %s has been uploaded.' % profile

        data = {'uploader': username,
                'item': profile,
                'server': upload_to
               }

        response = requests.post(base_url + "/uploaded", json.dumps(data))

        if response.status_code == 200:
            print '- Tracker acknowledged upload of %s.' % profile
            print '- Removing local copy of %s.' % profile

            shutil.rmtree(directory, ignore_errors=True)

            return True
        else:
            print '- Tracker error (status: %d, body: %s).' % (response.status_code, response.text)
            return False
    else:
        print '- Tracker error (status: %d, body: %s).' % (response.status_code, response.text)
        return False

# ------------------------------------------------------------------------------

if len(sys.argv) < 2:
    print "Usage: %s YOUR_USERNAME [PROFILE PROFILE...]" % sys.argv[0]
    print "If PROFILEs are given, only the given PROFILEs will be retrieved."
    print "Each PROFILE should be a string like /u/1234567/username."
    sys.exit(1)

username = sys.argv[1]
base_url = "http://fujoshi.at.ninjawedding.org"
upload_to = "fos.textfiles.com::fanfiction"

stop_threshold = time.time()

if len(sys.argv) >= 3:
    for profile in sys.argv[2::]:
        ok = archive(profile)

        if not ok:
            sys.exit(1)

else:
    while True:
        # Should we shut down?
        if os.path.isfile('STOP') and os.stat('STOP').st_mtime > stop_threshold:
            print "- STOP detected; terminating."
            sys.exit()

        # Get a profile.
        #
        # POST /request => [200, item] | [404, nothing] | [420, nothing]
        print "- Requesting work item."
        response = requests.post(base_url + "/request", json.dumps({'downloader': username}))
        profile = response.text

        if response.status_code == 404:
            print "  - Tracker returned 404; assuming todo queue is empty.  Exiting."
            sys.exit()

        if response.status_code == 420:
            print "  - Tracker is rate-limiting requests; will retry in 30 seconds."
            time.sleep(30)
            continue

        if response.status_code >= 500:
            print "  - Tracker returned an error; will retry in 30 seconds."
            time.sleep(30)
            continue

        if len(profile) == 0:
            print "  - Tracker returned an empty work item; will retry in 30 seconds."
            time.sleep(30)
            continue

        # If we got a profile path of non-zero length, fetch it.
        if response.status_code == 200:
            ok = archive(profile)

            if not ok:
                sys.exit(1)

# vim:ts=4:sw=4:et
