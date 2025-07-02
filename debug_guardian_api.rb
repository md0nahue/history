#!/usr/bin/env ruby

require 'httparty'
require 'json'

class GuardianDebugger
  include HTTParty
  
  base_uri 'https://content.guardianapis.com'
  
  def initialize
    @api_key = ENV['GUARDIAN_KEY']
    puts "Guardian Key present: #{@api_key.present?}"
  end
  
  def test_historical_dates
    # Test various historical dates
    test_dates = [
      [1999, 1, 1],
      [1995, 1, 1], 
      [1990, 1, 1],
      [1985, 1, 1],
      [1980, 1, 1],
      [1975, 1, 1],
      [1970, 1, 1],
      [1965, 1, 1],
      [1960, 1, 1],
      [1955, 1, 1],
      [1950, 1, 1],
      [1945, 1, 1],
      [1940, 1, 1],
      [1935, 1, 1],
      [1930, 1, 1]
    ]
    
    test_dates.each do |year, month, day|
      puts "\n=== Testing #{year}-#{month}-#{day} ==="
      result = fetch_articles_for_date(year, month, day)
      puts "Articles found: #{result.length}"
      if result.any?
        puts "First article: #{result.first[:title]}"
      end
      sleep(1) # Rate limiting
    end
  end
  
  def fetch_articles_for_date(year, month, day)
    date_str = sprintf("%04d-%02d-%02d", year, month, day)
    
    response = self.class.get("/search", {
      query: {
        'api-key' => @api_key,
        'from-date' => date_str,
        'to-date' => date_str,
        'page-size' => 5,
        'show-fields' => 'headline,trailText,byline,sectionName,webUrl,lastModified',
        'order-by' => 'newest'
      }
    })
    
    if response.success?
      parse_articles(response.parsed_response)
    else
      puts "Error: #{response.code} - #{response.body}"
      []
    end
  end
  
  private
  
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
        published_date: article['webPublicationDate']
      }
    end
  end
end

# Run the debugger
debugger = GuardianDebugger.new
debugger.test_historical_dates 