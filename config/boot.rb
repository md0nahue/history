ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Load environment variables from shell and .env file
require "dotenv"
Dotenv.load

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
