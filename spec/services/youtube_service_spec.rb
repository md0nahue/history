require 'rails_helper'

RSpec.describe YouTubeService, type: :service do
  let(:service) { YouTubeService.new }
  
  describe '#initialize' do
    it 'initializes without errors' do
      expect { YouTubeService.new }.not_to raise_error
    end
  end
  
  describe '#search_and_find_song' do
    let(:song_title) { 'Bohemian Rhapsody' }
    let(:artist) { 'Queen' }
    
    context 'when yt-dlp is available' do
      before do
        # Mock the Open3.capture3 call to simulate yt-dlp output
        allow(Open3).to receive(:capture3).and_return([
          mock_youtube_search_response,
          '',
          double(exitstatus: 0, success?: true)
        ])
      end
      
      it 'returns success with video data when song is found' do
        result = service.search_and_find_song(song_title, artist)
        
        expect(result[:success]).to be true
        expect(result[:title]).to eq('Bohemian Rhapsody - Queen')
        expect(result[:artist]).to eq('Queen Official')
        expect(result[:video_id]).to eq('fJ9rUzIMcZQ')
        expect(result[:embed_url]).to eq('https://www.youtube.com/embed/fJ9rUzIMcZQ')
        expect(result[:thumbnail_url]).to eq('https://img.youtube.com/vi/fJ9rUzIMcZQ/mqdefault.jpg')
        expect(result[:similarity_score]).to be > 0.7
      end
      
      it 'handles songs without artist parameter' do
        result = service.search_and_find_song(song_title)
        
        expect(result[:success]).to be true
        expect(result[:title]).to be_present
        expect(result[:video_id]).to be_present
      end
      
      it 'respects max_results parameter' do
        allow(Open3).to receive(:capture3).and_return([
          mock_multiple_youtube_results,
          '',
          double(exitstatus: 0, success?: true)
        ])
        
        result = service.search_and_find_song(song_title, artist, 3)
        
        expect(result[:success]).to be true
        # Should still return the best match, not necessarily the first one
        expect(result[:title]).to be_present
      end
      
      it 'returns error when no search results found' do
        allow(Open3).to receive(:capture3).and_return([
          '',
          '',
          double(exitstatus: 0, success?: true)
        ])
        
        result = service.search_and_find_song('NonexistentSong', 'NonexistentArtist')
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('No videos found')
      end
      
      it 'returns error when similarity threshold not met' do
        allow(Open3).to receive(:capture3).and_return([
          mock_low_similarity_response,
          '',
          double(exitstatus: 0, success?: true)
        ])
        
        result = service.search_and_find_song(song_title, artist, 5, 0.9)
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('No suitable match found')
      end
    end
    
    context 'when yt-dlp fails' do
      before do
        allow(Open3).to receive(:capture3).and_return([
          '',
          'yt-dlp: command not found',
          double(exitstatus: 1, success?: false)
        ])
      end
      
      it 'returns error when yt-dlp command fails' do
        result = service.search_and_find_song(song_title, artist)
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('yt-dlp search failed')
      end
    end
    
    context 'when JSON parsing fails' do
      before do
        allow(Open3).to receive(:capture3).and_return([
          'invalid json response',
          '',
          double(exitstatus: 0, success?: true)
        ])
      end
      
      it 'handles invalid JSON gracefully' do
        result = service.search_and_find_song(song_title, artist)
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('No videos found')
      end
    end
    
    context 'when exception occurs' do
      before do
        allow(Open3).to receive(:capture3).and_raise(StandardError, 'Test exception')
      end
      
      it 'handles exceptions gracefully' do
        result = service.search_and_find_song(song_title, artist)
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('Service error')
      end
    end
  end
  
  describe 'private methods' do
    describe '#search_youtube' do
      it 'constructs correct search query with artist' do
        allow(Open3).to receive(:capture3).and_return(['', '', double(exitstatus: 0, success?: true)])
        
        service.send(:search_youtube, 'Test Song', 'Test Artist', 3)
        
        expect(Open3).to have_received(:capture3).with(
          'yt-dlp',
          '--dump-json',
          '--no-playlist',
          '--max-downloads', '3',
          '--extractor-args', 'youtube:skip=dash',
          'ytsearch3:Test Song Test Artist'
        )
      end
      
      it 'constructs correct search query without artist' do
        allow(Open3).to receive(:capture3).and_return(['', '', double(exitstatus: 0, success?: true)])
        
        service.send(:search_youtube, 'Test Song', nil, 3)
        
        expect(Open3).to have_received(:capture3).with(
          'yt-dlp',
          '--dump-json',
          '--no-playlist',
          '--max-downloads', '3',
          '--extractor-args', 'youtube:skip=dash',
          'ytsearch3:Test Song'
        )
      end
    end
    
    describe '#find_best_match' do
      let(:search_results) do
        [
          { id: '1', title: 'Bohemian Rhapsody - Queen Official', uploader: 'Queen Official', duration: 354, url: 'https://youtube.com/watch?v=1' },
          { id: '2', title: 'Bohemian Rhapsody Cover', uploader: 'Cover Artist', duration: 360, url: 'https://youtube.com/watch?v=2' },
          { id: '3', title: 'Different Song', uploader: 'Other Artist', duration: 300, url: 'https://youtube.com/watch?v=3' }
        ]
      end
      
      it 'finds the best match with high similarity' do
        result = service.send(:find_best_match, 'Bohemian Rhapsody', 'Queen', search_results, 0.7)
        
        expect(result).not_to be_nil
        expect(result[:title]).to eq('Bohemian Rhapsody - Queen Official')
        expect(result[:similarity_score]).to be > 0.7
      end
      
      it 'returns nil when similarity threshold not met' do
        result = service.send(:find_best_match, 'Completely Different Song', 'Unknown Artist', search_results, 0.9)
        
        expect(result).to be_nil
      end
      
      it 'handles case insensitive matching' do
        result = service.send(:find_best_match, 'bohemian rhapsody', 'queen', search_results, 0.7)
        
        expect(result).not_to be_nil
        expect(result[:title]).to eq('Bohemian Rhapsody - Queen Official')
      end
    end
  end
  
  private
  
  def mock_youtube_search_response
    <<~JSON
      {"id": "fJ9rUzIMcZQ", "title": "Bohemian Rhapsody - Queen", "uploader": "Queen Official", "duration": 354, "view_count": 1000000, "webpage_url": "https://youtube.com/watch?v=fJ9rUzIMcZQ"}
    JSON
  end
  
  def mock_multiple_youtube_results
    <<~JSON
      {"id": "1", "title": "Bohemian Rhapsody Cover", "uploader": "Cover Artist", "duration": 360, "view_count": 100000, "webpage_url": "https://youtube.com/watch?v=1"}
      {"id": "fJ9rUzIMcZQ", "title": "Bohemian Rhapsody - Queen", "uploader": "Queen Official", "duration": 354, "view_count": 1000000, "webpage_url": "https://youtube.com/watch?v=fJ9rUzIMcZQ"}
      {"id": "2", "title": "Another Bohemian Rhapsody", "uploader": "Another Artist", "duration": 350, "view_count": 50000, "webpage_url": "https://youtube.com/watch?v=2"}
    JSON
  end
  
  def mock_low_similarity_response
    <<~JSON
      {"id": "xyz", "title": "Completely Different Song", "uploader": "Different Artist", "duration": 300, "view_count": 1000, "webpage_url": "https://youtube.com/watch?v=xyz"}
    JSON
  end
end 