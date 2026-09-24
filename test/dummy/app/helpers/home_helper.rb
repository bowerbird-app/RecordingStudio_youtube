module HomeHelper
  def youtube_plain(value)
    CGI.unescapeHTML(value.to_s)
  end
end
