class NytArchiveService
  include HTTParty
  
  base_uri 'https://api.nytimes.com/svc/archive/v1'
  
  def initialize
    @api_key = ENV['NYT_PUBLIC_KEY']
    @private_key = ENV['NYT_PRIVATE_KEY']
    
    # Debug output to see what's loaded
    Rails.logger.info "NYT Archive Service initialized"
    Rails.logger.info "Public Key present: #{@api_key.present?}"
    Rails.logger.info "Private Key present: #{@private_key.present?}"
    
    if @api_key.blank?
      Rails.logger.error "NYT_PUBLIC_KEY not found in environment variables"
    end
  end
  
  def fetch_articles_for_date(year, month, day)
    # NYT Archive API format: YYYY/M (single digit month, no leading zero)
    date_path = "#{year}/#{month}"
    
    response = self.class.get("/#{date_path}.json", {
      query: {
        'api-key' => @api_key
      }
    })
    
    # Save the full API response to a JSON file for inspection
    save_response_to_file(response, year, month, day)
    
    if response.success?
      parse_articles(response.parsed_response)
    else
      Rails.logger.error "NYT API Error: #{response.code} - #{response.body}"
      []
    end
  end
  
  private
  
  def save_response_to_file(response, year, month, day)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "nyt_response_#{year}_#{month}_#{timestamp}.json"
    filepath = Rails.root.join('tmp', 'nyt_responses', filename)
    
    # Ensure the directory exists
    FileUtils.mkdir_p(File.dirname(filepath))
    
    # Save the response
    File.write(filepath, JSON.pretty_generate({
      status_code: response.code,
      headers: response.headers,
      body: response.parsed_response,
      raw_body: response.body
    }))
    
    Rails.logger.info "NYT API response saved to: #{filepath}"
  end
  
  def parse_articles(response_data)
    return [] unless response_data && response_data['response']
    
    docs = response_data['response']['docs'] || []
    
    docs.map do |doc|
      {
        title: doc['headline']&.dig('main') || doc['headline']&.dig('print_headline') || 'No Title',
        url: doc['web_url'],
        abstract: doc['abstract'],
        byline: doc['byline']&.dig('original'),
        section: doc['section_name'],
        subsection: doc['subsection_name'],
        published_date: doc['pub_date']
      }
    end
  end
end 