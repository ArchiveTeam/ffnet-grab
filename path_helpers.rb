require File.expand_path('../constants', __FILE__)

module PathHelpers
  def story_dir_for(sid)
    "#{DOWNLOAD_TO}/#{sid[0..0]}/#{sid[0..1]}/#{sid[0..2]}/#{sid}"
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
end
