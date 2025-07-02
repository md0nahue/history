require 'open3'
require 'json'
require 'fuzzy_match'

class YouTubeService
  def initialize
    @downloads_dir = Rails.root.join('storage', 'downloads')
    FileUtils.mkdir_p(@downloads_dir) unless Dir.exist?(@downloads_dir)
    Rails.logger.info "YouTube Service initialized with downloads directory: #{@downloads_dir}"
  end
  
  def search_and_download_song(song_title, artist = nil, max_results = 5, similarity_threshold = 0.7)
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
      
      # Download the best match
      download_result = download_video_as_mp3(best_match)
      
      if download_result[:success]
        Rails.logger.info "Successfully downloaded: #{best_match[:title]}"
        return {
          success: true,
          title: best_match[:title],
          artist: best_match[:uploader],
          duration: best_match[:duration],
          file_path: download_result[:file_path],
          similarity_score: best_match[:similarity_score]
        }
      else
        Rails.logger.error "Failed to download video: #{download_result[:error]}"
        return { success: false, error: download_result[:error] }
      end
      
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
      return []
    end
  end
  
  def find_best_match(song_title, artist, search_results, threshold)
    # Create a combined search string for better matching
    search_string = artist ? "#{song_title} #{artist}".downcase : song_title.downcase
    
    # Create fuzzy matcher with the search results
    titles = search_results.map { |result| result[:title].downcase }
    matcher = FuzzyMatch.new(titles)
    
    # Find the best match
    best_match_title = matcher.find(search_string)
    
    if best_match_title
      # Find the corresponding result
      result = search_results.find { |r| r[:title].downcase == best_match_title }
      
      if result
        # Calculate similarity score
        similarity_score = matcher.find_with_score(search_string).last
        
        Rails.logger.info "Best match found: '#{result[:title]}' (score: #{similarity_score})"
        
        if similarity_score >= threshold
          result[:similarity_score] = similarity_score
          return result
        else
          Rails.logger.warn "Best match score (#{similarity_score}) below threshold (#{threshold})"
        end
      end
    end
    
    nil
  end
  
  def download_video_as_mp3(video_data)
    # Create a safe filename
    safe_title = video_data[:title].gsub(/[^\w\s-]/, '').gsub(/\s+/, '_')
    filename = "#{safe_title}_#{video_data[:id]}.mp3"
    file_path = @downloads_dir.join(filename)
    
    # Skip if file already exists
    if File.exist?(file_path)
      Rails.logger.info "File already exists: #{file_path}"
      return { success: true, file_path: file_path.to_s }
    end
    
    # Download command for MP3
    command = [
      'yt-dlp',
      '--extract-audio',
      '--audio-format', 'mp3',
      '--audio-quality', '0',  # Best quality
      '--output', file_path.to_s,
      '--no-playlist',
      video_data[:url]
    ]
    
    Rails.logger.info "Executing download command: #{command.join(' ')}"
    
    stdout, stderr, status = Open3.capture3(*command)
    
    if status.success?
      Rails.logger.info "Successfully downloaded: #{file_path}"
      return { success: true, file_path: file_path.to_s }
    else
      Rails.logger.error "Download failed: #{stderr}"
      return { success: false, error: stderr }
    end
  end
  
  def cleanup_old_downloads(max_age_days = 7)
    cutoff_time = Time.current - max_age_days.days
    
    Dir.glob(@downloads_dir.join('*.mp3')).each do |file_path|
      file_time = File.mtime(file_path)
      if file_time < cutoff_time
        File.delete(file_path)
        Rails.logger.info "Deleted old file: #{file_path}"
      end
    end
  end
end 