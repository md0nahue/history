class TroveService
  include HTTParty
  
  base_uri 'https://api.trove.nla.gov.au/v2'
  
  def initialize
    @api_key = ENV['TROVE_API_KEY'] || 'demo' # Trove allows demo key for testing
    @zone = 'newspaper' # Focus on newspapers
    
    # Debug output
    Rails.logger.info "Trove Service initialized"
    Rails.logger.info "Trove API Key present: #{@api_key.present?}"
  end
  
  def fetch_articles_for_date(year, month, day)
    # Format date for Trove API (YYYY-MM-DD)
    date_str = sprintf("%04d-%02d-%02d", year, month, day)
    
    response = self.class.get("/result", {
      query: {
        'key' => @api_key,
        'zone' => @zone,
        'q' => "date:#{date_str}",
        'n' => 10, # Number of results
        'encoding' => 'json',
        'include' => 'articletext'
      }
    })
    
    # Save the full API response to a JSON file for inspection
    save_response_to_file(response, year, month, day)
    
    if response.success?
      parse_articles(response.parsed_response)
    else
      Rails.logger.error "Trove API Error: #{response.code} - #{response.body}"
      []
    end
  end
  
  private
  
  def save_response_to_file(response, year, month, day)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "trove_response_#{year}_#{month}_#{day}_#{timestamp}.json"
    filepath = Rails.root.join('tmp', 'trove_responses', filename)
    
    # Ensure the directory exists
    FileUtils.mkdir_p(File.dirname(filepath))
    
    # Save the response
    File.write(filepath, JSON.pretty_generate({
      status_code: response.code,
      headers: response.headers,
      body: response.parsed_response,
      raw_body: response.body
    }))
    
    Rails.logger.info "Trove API response saved to: #{filepath}"
  end
  
  def parse_articles(response_data)
    return [] unless response_data && response_data['response']
    
    records = response_data['response']['zone']&.first&.dig('records', 'article') || []
    
    records.map do |article|
      {
        title: article['heading'] || 'No Title',
        url: article['troveUrl'],
        abstract: article['snippet'] || article['heading'],
        byline: article['corrections']&.first, # Trove doesn't have traditional bylines
        section: article['category'],
        subsection: article['subcategory'],
        published_date: article['date'],
        newspaper: article['title'],
        page: article['page'],
        article_id: article['id']
      }
    end
  end
end 