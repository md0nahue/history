class HistoricalNewsService
  def initialize
    @trove_service = TroveService.new
    @guardian_service = GuardianService.new
    @loc_service = LibraryOfCongressService.new
    
    Rails.logger.info "Historical News Service initialized"
  end
  
  def fetch_articles_for_date(year, month, day)
    # Determine which services to use based on the year
    if year <= 1963
      # Use both Trove and Library of Congress for historical content (1803-1963)
      Rails.logger.info "Using Trove and Library of Congress APIs for year #{year}"
      
      # Make concurrent requests to both services
      threads = []
      trove_articles = []
      loc_articles = []
      
      # Start Trove request in a thread
      threads << Thread.new do
        begin
          trove_articles = @trove_service.fetch_articles_for_date(year, month, day)
        rescue => e
          Rails.logger.error "Trove API error: #{e.message}"
          trove_articles = []
        end
      end
      
      # Start Library of Congress request in a thread
      threads << Thread.new do
        begin
          loc_articles = @loc_service.fetch_articles_for_date(year, month, day)
        rescue => e
          Rails.logger.error "Library of Congress API error: #{e.message}"
          loc_articles = []
        end
      end
      
      # Wait for both threads to complete
      threads.each(&:join)
      
      # Combine and mark sources
      articles = []
      articles.concat(trove_articles.map { |article| article.merge(source: 'Trove') })
      articles.concat(loc_articles.map { |article| article.merge(source: 'Library of Congress') })
      
      # Sort by relevance/date and limit to 10 total
      articles.first(10)
      
    elsif year >= 1999
      # Use Guardian for recent content (1999+)
      Rails.logger.info "Using Guardian API for year #{year}"
      articles = @guardian_service.fetch_articles_for_date(year, month, day)
      articles.map { |article| article.merge(source: 'Guardian') }
    else
      # Gap years (1964-1998) - try all services
      Rails.logger.info "Trying all APIs for year #{year}"
      articles = []
      
      # Try Guardian first (in case they have some content)
      guardian_articles = @guardian_service.fetch_articles_for_date(year, month, day)
      articles.concat(guardian_articles.map { |article| article.merge(source: 'Guardian') })
      
      # If no Guardian articles, try historical services
      if articles.empty?
        # Try Trove
        trove_articles = @trove_service.fetch_articles_for_date(year, month, day)
        articles.concat(trove_articles.map { |article| article.merge(source: 'Trove') })
        
        # Try Library of Congress
        loc_articles = @loc_service.fetch_articles_for_date(year, month, day)
        articles.concat(loc_articles.map { |article| article.merge(source: 'Library of Congress') })
      end
      
      articles
    end
  end
  
  def get_source_info(year)
    if year <= 1963
      {
        name: 'Trove & Library of Congress',
        description: 'Historical Australian and American newspapers from 1803-1963',
        url: 'https://trove.nla.gov.au/ & https://chroniclingamerica.loc.gov/'
      }
    elsif year >= 1999
      {
        name: 'The Guardian',
        description: 'International news from 1999 onwards',
        url: 'https://www.theguardian.com/'
      }
    else
      {
        name: 'Mixed Sources',
        description: 'Combined historical and recent news sources',
        url: nil
      }
    end
  end
end 