#!/usr/bin/env ruby

# Test script for YouTube Service
# Usage: ruby test_youtube_service.rb

require_relative 'config/environment'

puts "YouTube Service Test"
puts "==================="

# Initialize the service
youtube_service = YouTubeService.new

# Test cases
test_cases = [
  { title: "Bohemian Rhapsody", artist: "Queen" },
  { title: "Imagine", artist: "John Lennon" },
  { title: "Hotel California", artist: "Eagles" },
  { title: "Stairway to Heaven", artist: "Led Zeppelin" }
]

test_cases.each_with_index do |test_case, index|
  puts "\n#{index + 1}. Testing: #{test_case[:title]} by #{test_case[:artist]}"
  puts "-" * 50
  
  begin
    result = youtube_service.search_and_download_song(
      test_case[:title],
      test_case[:artist],
      5,  # max_results
      0.7  # similarity_threshold
    )
    
    if result[:success]
      puts "✅ SUCCESS!"
      puts "   Title: #{result[:title]}"
      puts "   Artist: #{result[:artist]}"
      puts "   Duration: #{result[:duration]} seconds"
      puts "   Similarity Score: #{result[:similarity_score]}"
      puts "   File Path: #{result[:file_path]}"
    else
      puts "❌ FAILED: #{result[:error]}"
    end
    
  rescue => e
    puts "❌ ERROR: #{e.message}"
    puts e.backtrace.first(3).join("\n")
  end
  
  # Add a small delay between requests
  sleep(2)
end

puts "\n" + "=" * 50
puts "Test completed!"
puts "Check the storage/downloads directory for downloaded files." 