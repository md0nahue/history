class GeminiService
  include HTTParty
  
  base_uri 'https://generativelanguage.googleapis.com/v1beta/models'
  
  def initialize
    @api_key = ENV['GEMINI_API_KEY']
    @model = 'gemini-2.5-flash-lite-preview-06-17'
    
    Rails.logger.info "Gemini Service initialized"
    Rails.logger.info "Gemini API Key present: #{@api_key.present?}"
    
    if @api_key.blank?
      Rails.logger.error "GEMINI_API_KEY not found in environment variables"
    end
  end
  
  def clean_ocr_text(ocr_text, newspaper_name = nil, date = nil)
    return ocr_text if @api_key.blank?
    
    # Ensure proper encoding
    ocr_text = ocr_text.to_s.force_encoding('UTF-8')
    newspaper_name = newspaper_name.to_s.force_encoding('UTF-8') if newspaper_name
    date = date.to_s.force_encoding('UTF-8') if date
    
    prompt = build_cleaning_prompt(ocr_text, newspaper_name, date)
    
    response = self.class.post("/#{@model}:generateContent?key=#{@api_key}", {
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
          temperature: 0.1,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 8192
        }
      }.to_json
    })
    
    if response.success?
      result = response.parsed_response
      cleaned_text = result.dig('candidates', 0, 'content', 'parts', 0, 'text')
      
      if cleaned_text.present?
        Rails.logger.info "Successfully cleaned OCR text using Gemini"
        cleaned_text
      else
        Rails.logger.warn "Gemini returned empty response, using original OCR text"
        ocr_text
      end
    else
      Rails.logger.error "Gemini API Error: #{response.code} - #{response.body}"
      ocr_text
    end
  rescue => e
    Rails.logger.error "Gemini API exception: #{e.message}"
    ocr_text
  end
  
  private
  
  def build_cleaning_prompt(ocr_text, newspaper_name, date)
    year = date&.split('-')&.first || "unknown"
    
    <<~PROMPT
      You are cleaning OCR text from "#{newspaper_name}" published in #{year}.

      The OCR text below is full of errors from scanning old newspapers. Clean it up to be readable while using vocabulary and writing style that would be believable for a #{year} newspaper.

      Be aggressive about fixing:
      - Character recognition errors (thc→the, w0rd→word, etc.)
      - Broken words and spacing
      - Missing punctuation
      - Line break issues
      - Nonsensical text fragments

      Use authentic #{year} newspaper language and style. Make it sound like a real newspaper article from that era.

      Return only the cleaned text:

      #{ocr_text}
    PROMPT
  end
end 