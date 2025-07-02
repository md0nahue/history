require 'open3'
require 'json'

class BillboardService
  def initialize
    @script_path = Rails.root.join('scripts', 'get_billboard_chart.py')
    @python_path = Rails.root.join('venv', 'bin', 'python3')
    Rails.logger.info "Billboard Service initialized with script path: #{@script_path}"
    Rails.logger.info "Python path: #{@python_path}"
  end
  
  def fetch_year_end_chart(year, chart_name = 'hot-100')
    Rails.logger.info "Fetching Billboard chart for year: #{year}, chart: #{chart_name}"
    
    # Save the request details for debugging
    save_request_to_file(year, chart_name)
    
    begin
      # Execute the Python script using the virtual environment
      stdout, stderr, status = Open3.capture3(
        @python_path.to_s, 
        @script_path.to_s, 
        year.to_s, 
        chart_name
      )
      
      # Save the raw response for debugging
      save_response_to_file(stdout, stderr, status, year, chart_name)
      
      if status.success?
        begin
          result = JSON.parse(stdout.strip)
          
          if result['success']
            Rails.logger.info "Successfully fetched Billboard chart for #{year} with #{result['entry_count']} entries"
            return parse_chart_data(result)
          else
            Rails.logger.error "Billboard API error: #{result['error']}"
            return []
          end
        rescue JSON::ParserError => e
          Rails.logger.error "Failed to parse JSON response: #{e.message}"
          Rails.logger.error "Raw stdout: #{stdout}"
          return []
        end
      else
        Rails.logger.error "Python script failed with status #{status.exitstatus}"
        Rails.logger.error "Stderr: #{stderr}"
        return []
      end
      
    rescue => e
      Rails.logger.error "Exception in BillboardService: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return []
    end
  end
  
  private
  
  def save_request_to_file(year, chart_name)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "billboard_request_#{year}_#{chart_name}_#{timestamp}.json"
    filepath = Rails.root.join('tmp', 'billboard_requests', filename)
    
    FileUtils.mkdir_p(File.dirname(filepath))
    
    request_data = {
      timestamp: Time.current.iso8601,
      year: year,
      chart_name: chart_name,
      script_path: @script_path.to_s
    }
    
    File.write(filepath, JSON.pretty_generate(request_data))
    Rails.logger.info "Billboard request saved to: #{filepath}"
  end
  
  def save_response_to_file(stdout, stderr, status, year, chart_name)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "billboard_response_#{year}_#{chart_name}_#{timestamp}.json"
    filepath = Rails.root.join('tmp', 'billboard_responses', filename)
    
    FileUtils.mkdir_p(File.dirname(filepath))
    
    response_data = {
      timestamp: Time.current.iso8601,
      year: year,
      chart_name: chart_name,
      exit_status: status.exitstatus,
      success: status.success?,
      stdout: stdout,
      stderr: stderr
    }
    
    # Try to parse JSON if available
    begin
      response_data[:parsed_json] = JSON.parse(stdout.strip) if stdout.strip.present?
    rescue JSON::ParserError
      response_data[:parsed_json] = nil
    end
    
    File.write(filepath, JSON.pretty_generate(response_data))
    Rails.logger.info "Billboard response saved to: #{filepath}"
  end
  
  def parse_chart_data(result)
    return [] unless result['entries']
    
    result['entries'].map do |entry|
      {
        title: entry['title'],
        artist: entry['artist'],
        rank: entry['rank'],
        image: entry['image'],
        chart_name: result['chart_name'],
        year: result['year']
      }
    end
  end
end 