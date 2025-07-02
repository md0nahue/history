# Historical News Explorer

A Rails application that displays a random year and fetches New York Times articles from that date using the NYT Archive API.

## Features

- Displays a random year between 1930 and today
- Fetches articles from the New York Times Archive API for that date
- Clean, modern UI with Tailwind CSS
- Saves full API responses to JSON files for inspection
- External links to NYT articles

## Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   ```

3. Configure your NYT API keys:
   - Edit the `.env` file in the root directory
   - Replace the placeholder values with your actual API keys:
   ```
   NYT_PUBLIC_KEY=your_actual_public_key_here
   NYT_PRIVATE_KEY=your_actual_private_key_here
   ```

4. Start the Rails server:
   ```bash
   rails server
   ```

5. Visit `http://localhost:3000` in your browser

## API Response Files

The application saves full API responses to JSON files in the `tmp/nyt_responses/` directory. These files contain:
- HTTP status codes
- Response headers
- Parsed response body
- Raw response body

This allows you to inspect the API responses and understand the data structure.

## How it Works

1. **Random Year Generation**: The app generates a random year between 1930 and the current year
2. **API Request**: Uses the NYT Archive API to fetch articles for January 1st of that year
3. **Fallback**: If no articles are found, tries June 15th as a fallback date
4. **Display**: Shows article titles, abstracts, bylines, and sections with links to the full articles

## Dependencies

- Rails 7.1.5
- HTTParty (for API requests)
- dotenv-rails (for environment variables)
- Tailwind CSS (for styling)

## API Documentation

The application uses the New York Times Archive API. For more information, visit:
https://developer.nytimes.com/docs/archive-product/1/overview
# history
