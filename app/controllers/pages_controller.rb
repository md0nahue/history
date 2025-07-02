class PagesController < ApplicationController
  def home
    # Generate a random year between 1803 (Trove starts) and today
    @random_year = rand(1803..Date.current.year)
    
    # Generate random month and day
    @random_month = rand(1..12)
    @random_day = rand(1..28) # Using 28 to avoid date issues
    
    # Fetch articles using the hybrid historical news service
    @news_service = HistoricalNewsService.new
    @articles = @news_service.fetch_articles_for_date(@random_year, @random_month, @random_day)
    
    # If no articles found, try a different date in the same year
    if @articles.empty?
      @random_month = 6  # Try June
      @random_day = 15   # Try the 15th
      @articles = @news_service.fetch_articles_for_date(@random_year, @random_month, @random_day)
    end
    
    # If still no articles, try a different year in the same era
    if @articles.empty?
      if @random_year <= 1963
        # Try a different historical year
        @random_year = rand(1803..1963)
      elsif @random_year >= 1999
        # Try a different recent year
        @random_year = rand(1999..Date.current.year)
      else
        # Try a year from either era
        @random_year = rand(1803..Date.current.year)
      end
      @random_month = rand(1..12)
      @random_day = rand(1..28)
      @articles = @news_service.fetch_articles_for_date(@random_year, @random_month, @random_day)
    end
    
    # Get source information for display
    @source_info = @news_service.get_source_info(@random_year)
    
    # Fetch popular songs for the date using the hybrid Historical Music Service
    # This will try Billboard first (1958+) and fall back to Gemini if needed
    @music_service = HistoricalMusicService.new
    if @random_year >= 1950
      begin
        date_string = "#{@random_year}-#{@random_month.to_s.rjust(2, '0')}-#{@random_day.to_s.rjust(2, '0')}"
        @popular_songs = @music_service.get_and_download_popular_songs(date_string, 5, 0.7)
        
        # If no songs found, try a different date in the same year
        if !@popular_songs[:success] || @popular_songs[:successful_finds] == 0
          @random_month = 6  # Try June
          @random_day = 15   # Try the 15th
          date_string = "#{@random_year}-#{@random_month.to_s.rjust(2, '0')}-#{@random_day.to_s.rjust(2, '0')}"
          @popular_songs = @music_service.get_and_download_popular_songs(date_string, 5, 0.7)
        end
      rescue => e
        Rails.logger.error "Error fetching popular songs: #{e.message}"
        @popular_songs = { success: false, error: e.message }
      end
    else
      @popular_songs = { success: false, error: "No music data available for years before 1950" }
    end
  end
  
  def loc_article
    @article_id = params[:id]
    @loc_service = LibraryOfCongressService.new
    @article_data = @loc_service.fetch_article_details(@article_id)
    
    if @article_data.nil?
      redirect_to root_path, alert: 'Article not found'
    end
  end
end 