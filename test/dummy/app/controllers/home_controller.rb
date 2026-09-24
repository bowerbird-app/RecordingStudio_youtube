class HomeController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @results = youtube_search
  rescue RecordingStudio::YouTube::Error => error
    @error = error.message
  end

  private

  def youtube_search
    return if @query.empty?

    options = { query: @query, max_results: 10 }
    token = params[:page_token].to_s.strip
    options[:page_token] = token unless token.empty?
    RecordingStudio::YouTube.search(**options)
  end
end
