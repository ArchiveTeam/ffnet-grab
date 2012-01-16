require File.expand_path('../constants', __FILE__)

module PathHelpers
  def story_dir_for(sid)
    "#{DOWNLOAD_TO}/stories/#{sid[0..0]}/#{sid[0..1]}/#{sid[0..2]}/#{sid}"
  end

  def temp_dir_for(dl)
    "#{TMPFS}/#{dl}"
  end

  def story_log_file(sid)
    "#{story_dir_for(sid)}/#{sid}.log"
  end

  def story_url_file(sid)
    "#{story_dir_for(sid)}/#{sid}_urls"
  end

  def story_warc_file(sid)
    "#{story_dir_for(sid)}/#{sid}"
  end

  def profile_dir_for(pid)
    "#{DOWNLOAD_TO}/profiles/#{pid[0..0]}/#{pid[0..1]}/#{pid[0..2]}/#{pid}"
  end

  def profile_log_file(pid)
    "#{profile_dir_for(pid)}/#{pid}.log"
  end

  def profile_warc_file(pid)
    "#{profile_dir_for(pid)}/#{pid}"
  end

  def profile_id(url)
    url =~ %r{(\d+)/?}
    $1
  end
end
