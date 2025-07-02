class GuardianService
  include HTTParty
  
  base_uri 'https://content.guardianapis.com'
  
  def initialize
    @api_key = ENV['GUARDIAN_KEY']
    
    # Debug output to see what's loaded
    Rails.logger.info "Guardian Service initialized"
    Rails.logger.info "Guardian Key present: #{@api_key.present?}"
    
    if @api_key.blank?
      Rails.logger.error "GUARDIAN_KEY not found in environment variables"
    end
  end
  
  def fetch_articles_for_date(year, month, day)
    # Format date as YYYY-MM-DD for Guardian API
    date_str = sprintf("%04d-%02d-%02d", year, month, day)
    
    response = self.class.get("/search", {
      query: {
        'api-key' => @api_key,
        'from-date' => date_str,
        'to-date' => date_str,
        'page-size' => 10,
        'show-fields' => 'headline,trailText,byline,sectionName,webUrl,lastModified',
        'show-tags' => 'contributor,series',
        'order-by' => 'newest'
      }
    })
    
    # Save the full API response to a JSON file for inspection
    save_response_to_file(response, year, month, day)
    
    if response.success?
      parse_articles(response.parsed_response)
    else
      Rails.logger.error "Guardian API Error: #{response.code} - #{response.body}"
      []
    end
  end
  
  private
  
  def save_response_to_file(response, year, month, day)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "guardian_response_#{year}_#{month}_#{day}_#{timestamp}.json"
    filepath = Rails.root.join('tmp', 'guardian_responses', filename)
    
    # Ensure the directory exists
    FileUtils.mkdir_p(File.dirname(filepath))
    
    # Save the response
    File.write(filepath, JSON.pretty_generate({
      status_code: response.code,
      headers: response.headers,
      body: response.parsed_response,
      raw_body: response.body
    }))
    
    Rails.logger.info "Guardian API response saved to: #{filepath}"
  end
  
  def parse_articles(response_data)
    return [] unless response_data && response_data['response']
    
    results = response_data['response']['results'] || []
    
    results.map do |article|
      {
        title: article['webTitle'] || 'No Title',
        url: article['webUrl'],
        abstract: article.dig('fields', 'trailText') || article['webTitle'],
        byline: article.dig('fields', 'byline'),
        section: article['sectionName'],
        subsection: article['subsectionName'],
        published_date: article['webPublicationDate'],
        tags: extract_tags(article['tags'])
      }
    end
  end
  
  def extract_tags(tags)
    return [] unless tags
    
    tags.map do |tag|
      {
        id: tag['id'],
        type: tag['type'],
        web_title: tag['webTitle']
      }
    end
  end
end 