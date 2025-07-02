require 'open3'
require 'json'
require 'fuzzy_match'

class YouTubeService
  def initialize
    Rails.logger.info "YouTube Service initialized"
  end
  
  def search_and_find_song(song_title, artist = nil, max_results = 5, similarity_threshold = 0.7)
    Rails.logger.info "Searching for song: #{song_title} by #{artist}"
    
    begin
      # Search for the song on YouTube
      search_results = search_youtube(song_title, artist, max_results)
      
      if search_results.empty?
        Rails.logger.warn "No search results found for: #{song_title}"
        return { success: false, error: "No videos found for '#{song_title}'" }
      end
      
      # Find the best match using fuzzy matching
      best_match = find_best_match(song_title, artist, search_results, similarity_threshold)
      
      if best_match.nil?
        Rails.logger.warn "No suitable match found for: #{song_title} (threshold: #{similarity_threshold})"
        return { success: false, error: "No suitable match found for '#{song_title}'" }
      end
      
      Rails.logger.info "Successfully found: #{best_match[:title]}"
      return {
        success: true,
        title: best_match[:title],
        artist: best_match[:uploader],
        duration: best_match[:duration],
        video_id: best_match[:id],
        video_url: best_match[:url],
        embed_url: "https://www.youtube.com/embed/#{best_match[:id]}",
        thumbnail_url: "https://img.youtube.com/vi/#{best_match[:id]}/mqdefault.jpg",
        similarity_score: best_match[:similarity_score]
      }
      
    rescue => e
      Rails.logger.error "Exception in YouTubeService: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return { success: false, error: "Service error: #{e.message}" }
    end
  end
  
  private
  
  def search_youtube(query, artist = nil, max_results = 5)
    search_query = artist ? "#{query} #{artist}" : query
    
    # Use yt-dlp to search YouTube
    command = [
      'yt-dlp',
      '--dump-json',
      '--no-playlist',
      '--max-downloads', max_results.to_s,
      '--extractor-args', 'youtube:skip=dash',
      "ytsearch#{max_results}:#{search_query}"
    ]
    
    Rails.logger.info "Executing search command: #{command.join(' ')}"
    
    stdout, stderr, status = Open3.capture3(*command)
    
    if status.success?
      results = []
      stdout.each_line do |line|
        begin
          video_data = JSON.parse(line.strip)
          results << {
            id: video_data['id'],
            title: video_data['title'],
            uploader: video_data['uploader'],
            duration: video_data['duration'],
            view_count: video_data['view_count'],
            url: video_data['webpage_url']
          }
        rescue JSON::ParserError => e
          Rails.logger.warn "Failed to parse video data: #{e.message}"
        end
      end
      
      Rails.logger.info "Found #{results.length} search results"
      return results
    else
      Rails.logger.error "yt-dlp search failed: #{stderr}"
      return [] if stderr.blank?
      raise "yt-dlp search failed: #{stderr}"
    end
  end
  
  def find_best_match(song_title, artist, search_results, threshold)
    # Create a combined search string for better matching
    search_string = artist ? "#{song_title} #{artist}".downcase : song_title.downcase
    
    # Create fuzzy matcher with the search results
    titles = search_results.map { |result| result[:title].downcase }
    matcher = FuzzyMatch.new(titles, must_match_at_least_one_word: true)
    
    # Find the best match
    best_match_title, similarity_score = matcher.find_with_score(search_string)
    
    if best_match_title
      # Find the corresponding result
      result = search_results.find { |r| r[:title].downcase == best_match_title }
      
      if result
        result[:similarity_score] = similarity_score
        return result if similarity_score >= threshold
      end
    end
    nil
  end
end 