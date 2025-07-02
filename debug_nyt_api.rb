#!/usr/bin/env ruby

require 'httparty'
require 'json'

# Load environment variables
require 'dotenv'
Dotenv.load

puts "=== NYT API Debug Script ==="
puts "Public Key present: #{!ENV['NYT_PUBLIC_KEY'].nil? && !ENV['NYT_PUBLIC_KEY'].empty?}"
puts "Private Key present: #{!ENV['NYT_PRIVATE_KEY'].nil? && !ENV['NYT_PRIVATE_KEY'].empty?}"

if ENV['NYT_PUBLIC_KEY'] && !ENV['NYT_PUBLIC_KEY'].empty?
  puts "Public Key (first 10 chars): #{ENV['NYT_PUBLIC_KEY'][0..9]}..."
else
  puts "ERROR: NYT_PUBLIC_KEY not found!"
  exit 1
end

# Test different API endpoints
test_cases = [
  { year: 2024, month: 1, description: "Recent month (2024-1)" },
  { year: 2020, month: 1, description: "Recent year (2020-1)" },
  { year: 1995, month: 1, description: "Older year (1995-1)" },
  { year: 1982, month: 1, description: "Much older year (1982-1)" }
]

test_cases.each do |test_case|
  puts "\n--- Testing #{test_case[:description]} ---"
  
  url = "https://api.nytimes.com/svc/archive/v1/#{test_case[:year]}/#{test_case[:month]}.json"
  puts "URL: #{url}"
  
  begin
    response = HTTParty.get(url, query: { 'api-key' => ENV['NYT_PUBLIC_KEY'] })
    
    puts "Status Code: #{response.code}"
    puts "Response Headers: #{response.headers}"
    
    if response.success?
      puts "SUCCESS! Response size: #{response.body.length} characters"
      
      # Try to parse JSON
      begin
        parsed = JSON.parse(response.body)
        puts "JSON parsed successfully"
        puts "Response keys: #{parsed.keys.join(', ')}"
        
        if parsed['response'] && parsed['response']['docs']
          puts "Number of articles: #{parsed['response']['docs'].length}"
          if parsed['response']['docs'].any?
            first_article = parsed['response']['docs'].first
            puts "First article title: #{first_article['headline']&.dig('main') || 'No title'}"
          end
        end
      rescue JSON::ParserError => e
        puts "Failed to parse JSON: #{e.message}"
        puts "First 200 chars of response: #{response.body[0..200]}"
      end
    else
      puts "ERROR: #{response.code} - #{response.body}"
    end
    
  rescue => e
    puts "Exception: #{e.message}"
    puts e.backtrace.first(3)
  end
end

puts "\n=== Testing with different API key format ==="
# Try with the private key if it exists
if ENV['NYT_PRIVATE_KEY'] && !ENV['NYT_PRIVATE_KEY'].empty?
  puts "Testing with private key..."
  url = "https://api.nytimes.com/svc/archive/v1/2024/1.json"
  
  response = HTTParty.get(url, query: { 'api-key' => ENV['NYT_PRIVATE_KEY'] })
  puts "Status Code: #{response.code}"
  puts "Response: #{response.body[0..200]}..."
end

puts "\n=== Testing API documentation example ==="
# Test the exact example from the documentation
url = "https://api.nytimes.com/svc/archive/v1/2024/1.json"
puts "Testing: #{url}"

response = HTTParty.get(url, query: { 'api-key' => ENV['NYT_PUBLIC_KEY'] })
puts "Status Code: #{response.code}"
puts "Response: #{response.body[0..200]}..." 