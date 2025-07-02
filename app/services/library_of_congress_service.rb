class LibraryOfCongressService
  include HTTParty
  
  base_uri 'https://chroniclingamerica.loc.gov'
  
  def initialize
    @gemini_service = GeminiService.new
    Rails.logger.info "Library of Congress Service initialized"
  end
  
  def fetch_articles_for_date(year, month, day)
    # Format date for LOC API (YYYY-MM-DD)
    date_str = sprintf("%04d-%02d-%02d", year, month, day)
    
    response = self.class.get("/search/pages/results", {
      query: {
        'dateFilterType' => 'range',
        'date1' => date_str,
        'date2' => date_str,
        'rows' => 10,
        'format' => 'json',
        'sort' => 'relevance'
      }
    })
    
    # Save the full API response to a JSON file for inspection
    save_response_to_file(response, year, month, day)
    
    if response.success?
      parse_articles(response.parsed_response)
    else
      Rails.logger.error "Library of Congress API Error: #{response.code} - #{response.body}"
      []
    end
  end
  
  def fetch_article_details(article_id)
    # Fetch the page details from the LOC API
    # article_id is the full path like "lccn/sn91068402/1895-02-28/ed-1/seq-2"
    response = self.class.get("/#{article_id}.json")
    
    if response.success?
      page_data = response.parsed_response
      
      # Fetch the OCR text
      ocr_response = self.class.get(page_data['text'], {
        headers: {
          'Accept' => 'text/plain; charset=utf-8'
        }
      })
      
      if ocr_response.success?
        # Handle encoding issues - force UTF-8 encoding
        raw_ocr_text = ocr_response.body.force_encoding('UTF-8')
        Rails.logger.info "OCR text encoding: #{raw_ocr_text.encoding}, length: #{raw_ocr_text.length}"
        newspaper_name = page_data.dig('title', 'name')
        date_issued = page_data.dig('issue', 'date_issued')
        
        # Clean the OCR text using Gemini
        begin
          cleaned_ocr_text = @gemini_service.clean_ocr_text(raw_ocr_text, newspaper_name, date_issued)
        rescue => e
          Rails.logger.error "Failed to clean OCR text: #{e.message}"
          cleaned_ocr_text = raw_ocr_text # Fall back to original text
        end
        
        {
          page_data: page_data,
          ocr_text: cleaned_ocr_text,
          raw_ocr_text: raw_ocr_text, # Keep original for comparison
          pdf_url: page_data['pdf'],
          jp2_url: page_data['jp2'],
          newspaper_name: newspaper_name,
          date_issued: date_issued,
          sequence: page_data['sequence']
        }
      else
        Rails.logger.error "Failed to fetch OCR text: #{ocr_response.code}"
        nil
      end
    else
      Rails.logger.error "Failed to fetch article details: #{response.code}"
      nil
    end
  end
  
  private
  
  def save_response_to_file(response, year, month, day)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "loc_response_#{year}_#{month}_#{day}_#{timestamp}.json"
    filepath = Rails.root.join('tmp', 'loc_responses', filename)
    
    # Ensure the directory exists
    FileUtils.mkdir_p(File.dirname(filepath))
    
    # Save the response
    File.write(filepath, JSON.pretty_generate({
      status_code: response.code,
      headers: response.headers,
      body: response.parsed_response,
      raw_body: response.body
    }))
    
    Rails.logger.info "Library of Congress API response saved to: #{filepath}"
  end
  
  def parse_articles(response_data)
    return [] unless response_data && response_data['items']
    
    response_data['items'].map do |article|
      {
        title: article['title'] || 'No Title',
        url: "/loc_article/#{article['id']}", # Point to our internal route
        abstract: article['ocr_eng']&.truncate(200) || article['title'],
        byline: nil, # LOC doesn't provide bylines
        section: article['section'],
        subsection: nil,
        published_date: article['date'],
        newspaper: article['title_normal'],
        page: article['page'],
        article_id: article['id'],
        state: article['state'],
        city: article['city']
      }
    end
  end
end 