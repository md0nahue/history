# Filename: chronicling_america_searcher.rb

require 'httparty'
require 'json'

# A class to search the Chronicling America API and retrieve full text for articles.
class ChroniclingAmericaSearcher
  # The base URL for the search API
  BASE_SEARCH_URL = 'https://chroniclingamerica.loc.gov/search/pages/results/'

  # The main method to perform the search.
  # @param date_string [String] The date to search for in 'YYYY-MM-DD' format.
  # @return [Array<Hash>] An array of hashes, where each hash represents an article.
  def search_by_date(date_string)
    puts "Searching for pages from #{date_string}..."

    # Step 1: Search for pages on the given date
    # We set both date1 and date2 to the same value for a single-day search.
    # format=json tells the API to return JSON data.
    response = HTTParty.get(BASE_SEARCH_URL, query: {
      date1: date_string,
      date2: date_string,
      format: 'json'
    })

    # Error handling for the initial search
    unless response.ok?
      puts "Error: Failed to fetch search results. Status code: #{response.code}"
      return []
    end

    search_results = response.parsed_response
    pages = search_results['items']

    if pages.empty?
      puts "No pages found for #{date_string}."
      return []
    end
    
    puts "Found #{pages.length} pages. Now fetching full text for each..."

    # Step 2: Iterate through each page result and fetch its full text.
    # We use `map` to transform the array of page results into our desired format.
    articles = pages.map.with_index do |page, index|
      puts "  -> Processing page #{index + 1} of #{pages.length}: #{page['title']}..."
      
      # The 'url' key in the result points to the JSON for that specific page
      full_text = get_full_text(page['url'])

      # Assemble a clean hash with the information we care about
      {
        title: page['title'],
        date: page['date'],
        city: page['city']&.first, # city is an array, take the first
        state: page['state']&.first, # state is an array, take the first
        lccn: page['lccn'],
        full_text: full_text
      }
    end

    articles
  end

  private

  # Helper method to fetch the full text from a specific page's JSON URL.
  # @param page_json_url [String] The URL pointing to the page's JSON data.
  # @return [String] The OCR full text of the article or an error message.
  def get_full_text(page_json_url)
    # Ensure we are requesting the JSON representation of the page
    url = page_json_url.end_with?('.json') ? page_json_url : "#{page_json_url}.json"
    
    response = HTTParty.get(url)
    
    if response.ok?
      # The full text is stored in the 'ocr_eng' key
      response.parsed_response['ocr_eng'] || 'Full text (OCR) not available for this page.'
    else
      "Could not retrieve full text. Status: #{response.code}"
    end
  rescue StandardError => e
    "An error occurred while fetching full text: #{e.message}"
  end
end

# --- Example Usage ---
if __FILE__ == $0
  searcher = ChroniclingAmericaSearcher.new
  
  # Let's search for a historic date, like the day after the Titanic sank.
  # date_to_search = '1912-04-16' 
  
  # Or a date from the turn of the century
  date_to_search = '1960-01-01'

  begin
    articles = searcher.search_by_date(date_to_search)

    if articles.any?
      puts "\n--- Search Complete! Found #{articles.length} articles for #{date_to_search} ---\n"
      
      # Print the details for the first 3 articles found
      articles.first(3).each_with_index do |article, index|
        puts "=============== Article ##{index + 1} ==============="
        puts "Title: #{article[:title]}"
        puts "Date: #{article[:date]}"
        puts "Location: #{article[:city]}, #{article[:state]}"
        puts "LCCN: #{article[:lccn]}"
        puts "--- Full Text (first 300 characters) ---"
        puts (article[:full_text] || "No text found.")[0..300] + "..."
        puts "========================================\n\n"
      end
    else
      puts "\n--- Search finished with no results. ---"
    end

  rescue StandardError => e
    puts "\nA critical error occurred: #{e.message}"
    puts e.backtrace.join("\n")
  end
end