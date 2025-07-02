require 'json'

class HistoricalMusicService
  def initialize
    @gemini_service = GeminiService.new
    @youtube_service = YouTubeService.new
    @billboard_service = BillboardService.new
    Rails.logger.info "Historical Music Service initialized"
  end
  
  def get_and_download_popular_songs(date, max_songs = 5, similarity_threshold = 0.7)
    Rails.logger.info "Getting popular songs for date: #{date}"
    
    begin
      # Parse the date
      parsed_date = Date.parse(date.to_s)
      
      # Try Billboard first (only for years 1958+ when Billboard Hot 100 started)
      songs_data = []
      if parsed_date.year >= 1958
        songs_data = get_songs_from_billboard(parsed_date, max_songs)
        Rails.logger.info "Billboard returned #{songs_data.length} songs"
      end
      
      # If Billboard didn't return enough songs, try Gemini
      if songs_data.length < max_songs
        remaining_songs = max_songs - songs_data.length
        Rails.logger.info "Getting #{remaining_songs} additional songs from Gemini"
        
        gemini_songs = get_popular_songs_from_gemini(date, remaining_songs)
        songs_data.concat(gemini_songs)
        
        Rails.logger.info "Total songs after Gemini: #{songs_data.length}"
      end
      
      if songs_data.empty?
        Rails.logger.warn "No songs found for date: #{date}"
        return { success: false, error: "No popular songs found for #{date}" }
      end
      
      # Find YouTube videos for each song
      results = []
      songs_data.each_with_index do |song_info, index|
        Rails.logger.info "Processing song #{index + 1}/#{songs_data.length}: #{song_info[:title]} by #{song_info[:artist]}"
        
        youtube_result = @youtube_service.search_and_find_song(
          song_info[:title],
          song_info[:artist],
          3,  # max_results - keep it low for better matches
          similarity_threshold
        )
        
        if youtube_result[:success]
          results << {
            original_song: song_info,
            youtube_result: youtube_result,
            status: 'success',
            source: song_info[:source] || 'unknown'
          }
          Rails.logger.info "✅ Successfully found: #{song_info[:title]}"
        else
          results << {
            original_song: song_info,
            youtube_result: youtube_result,
            status: 'failed',
            error: youtube_result[:error],
            source: song_info[:source] || 'unknown'
          }
          Rails.logger.warn "❌ Failed to find: #{song_info[:title]} - #{youtube_result[:error]}"
        end
        
        # Add delay between searches to be respectful
        sleep(1) if index < songs_data.length - 1
      end
      
      success_count = results.count { |r| r[:status] == 'success' }
      Rails.logger.info "Found #{success_count}/#{songs_data.length} songs for #{date}"
      
      return {
        success: true,
        date: date,
        total_songs: songs_data.length,
        successful_finds: success_count,
        results: results
      }
      
    rescue => e
      Rails.logger.error "Exception in HistoricalMusicService: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return { success: false, error: "Service error: #{e.message}" }
    end
  end
  
  private
  
  def get_songs_from_billboard(date, max_songs)
    begin
      # Try to get Billboard chart data for the year
      chart_data = @billboard_service.fetch_year_end_chart(date.year, 'hot-100')
      
      if chart_data.empty?
        # Try alternative chart if hot-100 is empty
        chart_data = @billboard_service.fetch_year_end_chart(date.year, 'pop-songs')
      end
      
      if chart_data.any?
        # Take the top songs from the chart
        chart_data.first(max_songs).map do |song|
          {
            title: song[:title],
            artist: song[:artist],
            year: date.year,
            rank: song[:rank],
            source: 'Billboard',
            reason: "Ranked ##{song[:rank]} on Billboard Hot 100 in #{date.year}"
          }
        end
      else
        []
      end
    rescue => e
      Rails.logger.error "Billboard service error: #{e.message}"
      []
    end
  end
  
  def get_popular_songs_from_gemini(date, max_songs)
    return [] if @gemini_service.instance_variable_get(:@api_key).blank?
    
    # Parse the date
    begin
      parsed_date = Date.parse(date.to_s)
    rescue ArgumentError
      Rails.logger.error "Invalid date format: #{date}"
      return []
    end
    
    prompt = build_songs_prompt(parsed_date, max_songs)
    
    response = @gemini_service.class.post("/#{@gemini_service.instance_variable_get(:@model)}:generateContent?key=#{@gemini_service.instance_variable_get(:@api_key)}", {
      headers: {
        'Content-Type' => 'application/json'
      },
      body: {
        contents: [{
          parts: [{
            text: prompt
          }]
        }],
        generationConfig: {
          temperature: 0.3,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048
        }
      }.to_json
    })
    
    if response.success?
      result = response.parsed_response
      songs_text = result.dig('candidates', 0, 'content', 'parts', 0, 'text')
      
      if songs_text.present?
        parse_songs_response(songs_text, parsed_date)
      else
        Rails.logger.warn "Gemini returned empty response for songs"
        []
      end
    else
      Rails.logger.error "Gemini API Error: #{response.code} - #{response.body}"
      []
    end
  rescue => e
    Rails.logger.error "Gemini API exception: #{e.message}"
    []
  end
  
  def build_songs_prompt(date, max_songs)
    year = date.year
    month = date.month
    day = date.day
    
    <<~PROMPT
      You are a music historian. For the date #{month}/#{day}/#{year}, provide exactly #{max_songs} songs that were popular in the United States around that time.

      IMPORTANT: Return ONLY a JSON array of objects with this exact structure:
      [
        {
          "title": "Song Title",
          "artist": "Artist Name",
          "year": #{year},
          "reason": "Brief reason why this song was popular"
        }
      ]

      Guidelines:
      - Focus on songs that were actually popular/released around #{year} (±2 years)
      - Choose songs that would be findable on YouTube today
      - Include a mix of different genres and artists
      - Make sure the song titles and artist names are accurate
      - The "reason" should be brief (1-2 sentences max)
      - Avoid songs that are too obscure or hard to find

      Return ONLY the JSON array, no other text:
    PROMPT
  end
  
  def parse_songs_response(response_text, date)
    # Try to extract JSON from the response
    json_match = response_text.match(/\[.*\]/m)
    
    if json_match
      begin
        songs_data = JSON.parse(json_match[0])
        
        # Validate and clean the data
        songs_data.map do |song|
          {
            title: song['title']&.strip,
            artist: song['artist']&.strip,
            year: song['year'] || date.year,
            reason: song['reason']&.strip,
            source: 'Gemini'
          }.compact
        end.select { |song| song[:title].present? && song[:artist].present? }
        
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse JSON from Gemini response: #{e.message}"
        Rails.logger.error "Response text: #{response_text}"
        []
      end
    else
      Rails.logger.error "No JSON array found in Gemini response"
      Rails.logger.error "Response text: #{response_text}"
      []
    end
  end
end 