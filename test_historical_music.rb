#!/usr/bin/env ruby

# Test script for Historical Music Service
# Usage: ruby test_historical_music.rb

require_relative 'config/environment'

puts "Historical Music Service Test"
puts "============================"

# Initialize the service
music_service = HistoricalMusicService.new

# Test dates - different eras to see variety
test_dates = [
  "1969-07-20",  # Moon landing era
  "1985-07-13",  # Live Aid era  
  "1991-12-25",  # Early 90s
  "2001-09-11",  # Early 2000s
  "2010-01-01"   # Recent era
]

test_dates.each_with_index do |date, index|
  puts "\n#{index + 1}. Testing date: #{date}"
  puts "=" * 50
  
  begin
    result = music_service.get_and_download_popular_songs(
      date,
      3,    # max_songs - keep it small for testing
      0.7   # similarity_threshold
    )
    
    if result[:success]
      puts "✅ SUCCESS!"
      puts "   Date: #{result[:date]}"
      puts "   Total songs requested: #{result[:total_songs]}"
      puts "   Successfully found: #{result[:successful_finds]}"
      
      puts "\n   Results:"
      result[:results].each_with_index do |song_result, song_index|
        if song_result[:status] == 'success'
          puts "   ✅ #{song_index + 1}. #{song_result[:original_song][:title]} by #{song_result[:original_song][:artist]}"
          puts "      Found: #{song_result[:youtube_result][:title]}"
          puts "      Video ID: #{song_result[:youtube_result][:video_id]}"
          puts "      Embed URL: #{song_result[:youtube_result][:embed_url]}"
          puts "      Similarity: #{song_result[:youtube_result][:similarity_score]}"
          puts "      Source: #{song_result[:original_song][:source]}"
        else
          puts "   ❌ #{song_index + 1}. #{song_result[:original_song][:title]} by #{song_result[:original_song][:artist]}"
          puts "      Error: #{song_result[:error]}"
        end
      end
    else
      puts "❌ FAILED: #{result[:error]}"
    end
    
  rescue => e
    puts "❌ ERROR: #{e.message}"
    puts e.backtrace.first(3).join("\n")
  end
  
  # Add delay between date tests
  sleep(3) if index < test_dates.length - 1
end

puts "\n" + "=" * 50
puts "Test completed!"
puts "YouTube videos found and ready for embedding." 