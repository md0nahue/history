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
    
    # Fetch Billboard chart data for the year (only if year >= 1958 when Billboard Hot 100 started)
    @billboard_service = BillboardService.new
    if @random_year >= 1958
      @billboard_chart = @billboard_service.fetch_year_end_chart(@random_year, 'hot-100')
      
      # If no Billboard data, try a different chart
      if @billboard_chart.empty?
        @billboard_chart = @billboard_service.fetch_year_end_chart(@random_year, 'pop-songs')
      end
    else
      @billboard_chart = []
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