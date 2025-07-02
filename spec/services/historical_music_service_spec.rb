require 'rails_helper'
require_relative '../../app/services/historical_music_service'
require_relative '../../app/services/youtube_service'
require_relative '../../app/services/gemini_service'
require_relative '../../app/services/billboard_service'

RSpec.describe HistoricalMusicService, type: :service do
  let(:service) { HistoricalMusicService.new }
  let(:date) { '1969-07-20' }
  
  describe '#initialize' do
    it 'initializes without errors' do
      expect { HistoricalMusicService.new }.not_to raise_error
    end
    
    it 'initializes required services' do
      expect(service.instance_variable_get(:@gemini_service)).to be_a(GeminiService)
      expect(service.instance_variable_get(:@youtube_service)).to be_a(YouTubeService)
      expect(service.instance_variable_get(:@billboard_service)).to be_a(BillboardService)
    end
  end
  
  describe '#get_and_download_popular_songs' do
    context 'when Billboard data is available (1958+)' do
      let(:date) { '1969-07-20' }
      
      before do
        # Mock Billboard service to return data
        allow(service.instance_variable_get(:@billboard_service)).to receive(:fetch_year_end_chart)
          .with(1969, 'hot-100')
          .and_return(mock_billboard_data)
        
        # Mock YouTube service
        allow(service.instance_variable_get(:@youtube_service)).to receive(:search_and_find_song)
          .and_return(mock_youtube_success)
      end
      
      it 'uses Billboard data when available' do
        result = service.get_and_download_popular_songs(date, 3, 0.7)
        
        expect(result[:success]).to be true
        expect(result[:total_songs]).to eq(3)
        expect(result[:successful_finds]).to eq(3)
        expect(result[:results].first[:original_song][:source]).to eq('Billboard')
      end
      
      it 'falls back to pop-songs chart if hot-100 is empty' do
        allow(service.instance_variable_get(:@billboard_service)).to receive(:fetch_year_end_chart)
          .with(1969, 'hot-100')
          .and_return([])
        allow(service.instance_variable_get(:@billboard_service)).to receive(:fetch_year_end_chart)
          .with(1969, 'pop-songs')
          .and_return(mock_billboard_data)
        
        result = service.get_and_download_popular_songs(date, 3, 0.7)
        
        expect(result[:success]).to be true
        expect(result[:results].first[:original_song][:source]).to eq('Billboard')
      end
      
      it 'combines Billboard and Gemini data when needed' do
        # Billboard returns only 1 song, need 3 total
        allow(service.instance_variable_get(:@billboard_service)).to receive(:fetch_year_end_chart)
          .and_return(mock_billboard_data.first(1))
        
        # Mock Gemini service
        allow(service.instance_variable_get(:@gemini_service).class).to receive(:post)
          .and_return(mock_gemini_response)
        
        result = service.get_and_download_popular_songs(date, 3, 0.7)
        
        expect(result[:success]).to be true
        expect(result[:total_songs]).to eq(3)
        expect(result[:results].map { |r| r[:original_song][:source] }).to include('Billboard', 'Gemini')
      end
    end
    
    context 'when Billboard data is not available (pre-1958)' do
      let(:date) { '1950-01-01' }
      
      before do
        # Mock Gemini service
        allow(service.instance_variable_get(:@gemini_service).class).to receive(:post)
          .and_return(mock_gemini_response)
        
        # Mock YouTube service
        allow(service.instance_variable_get(:@youtube_service)).to receive(:search_and_find_song)
          .and_return(mock_youtube_success)
      end
      
      it 'uses only Gemini data for pre-1958 dates' do
        result = service.get_and_download_popular_songs(date, 3, 0.7)
        
        expect(result[:success]).to be true
        expect(result[:results].first[:original_song][:source]).to eq('Gemini')
      end
    end
    
    context 'when no data is available' do
      before do
        allow(service.instance_variable_get(:@billboard_service)).to receive(:fetch_year_end_chart)
          .and_return([])
        allow(service.instance_variable_get(:@gemini_service).class).to receive(:post)
          .and_return(mock_gemini_empty_response)
      end
      
      it 'returns error when no songs found' do
        result = service.get_and_download_popular_songs(date, 3, 0.7)
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('No popular songs found')
      end
    end
    
    context 'when YouTube service fails' do
      before do
        allow(service.instance_variable_get(:@billboard_service)).to receive(:fetch_year_end_chart)
          .and_return(mock_billboard_data)
        allow(service.instance_variable_get(:@youtube_service)).to receive(:search_and_find_song)
          .and_return(mock_youtube_failure)
      end
      
      it 'handles YouTube failures gracefully' do
        result = service.get_and_download_popular_songs(date, 3, 0.7)
        
        expect(result[:success]).to be true
        expect(result[:successful_finds]).to eq(0)
        expect(result[:results].first[:status]).to eq('failed')
      end
    end
    
    context 'when exception occurs' do
      before do
        allow(service.instance_variable_get(:@billboard_service)).to receive(:fetch_year_end_chart)
          .and_raise(StandardError, 'Test exception')
      end
      
      it 'handles exceptions gracefully' do
        result = service.get_and_download_popular_songs(date, 3, 0.7)
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('Service error')
      end
    end
  end
  
  describe 'private methods' do
    describe '#get_songs_from_billboard' do
      let(:date) { Date.parse('1969-07-20') }
      
      it 'transforms Billboard data correctly' do
        allow(service.instance_variable_get(:@billboard_service)).to receive(:fetch_year_end_chart)
          .and_return(mock_billboard_data)
        
        result = service.send(:get_songs_from_billboard, date, 3)
        
        expect(result.length).to eq(3)
        expect(result.first[:title]).to eq('Bohemian Rhapsody')
        expect(result.first[:artist]).to eq('Queen')
        expect(result.first[:source]).to eq('Billboard')
        expect(result.first[:reason]).to include('Ranked #1 on Billboard Hot 100')
      end
      
      it 'returns empty array when Billboard service fails' do
        allow(service.instance_variable_get(:@billboard_service)).to receive(:fetch_year_end_chart)
          .and_raise(StandardError, 'Billboard error')
        
        result = service.send(:get_songs_from_billboard, date, 3)
        
        expect(result).to eq([])
      end
    end
    
    describe '#get_popular_songs_from_gemini' do
      let(:date) { '1969-07-20' }
      
      it 'calls Gemini API with correct parameters' do
        allow(service.instance_variable_get(:@gemini_service).class).to receive(:post)
          .and_return(mock_gemini_response)
        
        service.send(:get_popular_songs_from_gemini, date, 3)
        
        expect(service.instance_variable_get(:@gemini_service).class).to have_received(:post)
      end
      
      it 'parses Gemini response correctly' do
        allow(service.instance_variable_get(:@gemini_service).class).to receive(:post)
          .and_return(mock_gemini_response)
        
        result = service.send(:get_popular_songs_from_gemini, date, 3)
        
        expect(result.length).to eq(3)
        expect(result.first[:title]).to eq('Bohemian Rhapsody')
        expect(result.first[:artist]).to eq('Queen')
        expect(result.first[:source]).to eq('Gemini')
      end
      
      it 'handles empty Gemini response' do
        allow(service.instance_variable_get(:@gemini_service).class).to receive(:post)
          .and_return(mock_gemini_empty_response)
        
        result = service.send(:get_popular_songs_from_gemini, date, 3)
        
        expect(result).to eq([])
      end
    end
    
    describe '#parse_songs_response' do
      let(:date) { Date.parse('1969-07-20') }
      
      it 'parses valid JSON response' do
        json_response = '[{"title": "Test Song", "artist": "Test Artist", "year": 1969, "reason": "Test reason"}]'
        
        result = service.send(:parse_songs_response, json_response, date)
        
        expect(result.length).to eq(1)
        expect(result.first[:title]).to eq('Test Song')
        expect(result.first[:artist]).to eq('Test Artist')
        expect(result.first[:source]).to eq('Gemini')
      end
      
      it 'handles invalid JSON gracefully' do
        result = service.send(:parse_songs_response, 'invalid json', date)
        
        expect(result).to eq([])
      end
      
      it 'filters out songs with missing title or artist' do
        json_response = '[{"title": "Test Song", "artist": "Test Artist"}, {"title": "", "artist": "Test Artist"}, {"title": "Test Song"}]'
        
        result = service.send(:parse_songs_response, json_response, date)
        
        expect(result.length).to eq(1)
        expect(result.first[:title]).to eq('Test Song')
      end
    end
  end
  
  private
  
  def mock_billboard_data
    [
      { title: 'Bohemian Rhapsody', artist: 'Queen', rank: 1, image: 'test.jpg' },
      { title: 'Imagine', artist: 'John Lennon', rank: 2, image: 'test.jpg' },
      { title: 'Hotel California', artist: 'Eagles', rank: 3, image: 'test.jpg' }
    ]
  end
  
  def mock_youtube_success
    {
      success: true,
      title: 'Bohemian Rhapsody - Queen',
      artist: 'Queen Official',
      duration: 354,
      video_id: 'fJ9rUzIMcZQ',
      embed_url: 'https://www.youtube.com/embed/fJ9rUzIMcZQ',
      similarity_score: 0.85
    }
  end
  
  def mock_youtube_failure
    {
      success: false,
      error: 'No videos found'
    }
  end
  
  def mock_gemini_response
    double(
      success?: true,
      parsed_response: {
        'candidates' => [{
          'content' => {
            'parts' => [{
              'text' => '[{"title": "Bohemian Rhapsody", "artist": "Queen", "year": 1969, "reason": "Popular rock song"}, {"title": "Imagine", "artist": "John Lennon", "year": 1969, "reason": "Iconic peace anthem"}, {"title": "Hotel California", "artist": "Eagles", "year": 1969, "reason": "Classic rock hit"}]'
            }]
          }
        }]
      }
    )
  end
  
  def mock_gemini_empty_response
    double(
      success?: true,
      parsed_response: {
        'candidates' => [{
          'content' => {
            'parts' => [{
              'text' => ''
            }]
          }
        }]
      }
    )
  end
end 