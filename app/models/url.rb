class Url < ApplicationRecord
  # Required libraries
  require 'base64'
  require 'digest'
  require 'securerandom'

  #=============================
  # Constants
  #=============================
  
  # Key length constants
  SHORT_KEY_LENGTH = 6   # Default key length (used first)
  LONG_KEY_LENGTH = 8    # Extended key length (used as fallback)
  MAX_ATTEMPTS = 5       # Maximum attempts per strategy
  MAX_RECURSION_DEPTH = 10 # Maximum recursion depth for encode method
  
  #=============================
  # Validations
  #=============================
  validates :original_url, presence: true, uniqueness: true
  validates :shortened_key, presence: true, uniqueness: true

  #=============================
  # Callbacks
  #=============================
  # TODO: Add before_validation callbacks
  #       - `validate_url_format` :
  #          We need to check if the original_url is valid
  #       - `check_if_url_exists` : (currently will be implemented as controller)
  #         If presents, there is no need to generate a new shortened_key
  #         We can just return the existing shortened_key
  #       - `normalize_url` :
  #        Normalize the original_url before saving to the database (concerns/url_normalize.rb)


  before_validation :generate_shortened_key, on: :create, if: -> { original_url.present? }

  #=============================
  # Public Class Methods
  #=============================
  
  # Converts an original URL into a shortened key
  # 
  # @param url [String] the URL to encode
  # @param attempt [Integer] current attempt counter (for collision handling)
  # @param use_long_key [Boolean] whether to use the longer key format
  # @param depth [Integer] current recursion depth
  # @return [String] the shortened key for this URL
  def self.encode(url, attempt = 0, use_long_key = false, depth = 0)
    # Prevent stack overflow from excessive recursion
    if depth >= MAX_RECURSION_DEPTH
      # Generate a random key if we've gone too deep
      return SecureRandom.urlsafe_base64(6).gsub(/=+$/, '')[0...(use_long_key ? LONG_KEY_LENGTH : SHORT_KEY_LENGTH)]
    end
    
    # Create a digest based on the URL and attempt count
    digest = if attempt == 0
      # First attempt uses just the URL for deterministic output
      Digest::MD5.hexdigest(url)[0...10]
    else
      # Subsequent attempts add the counter for uniqueness
      Digest::MD5.hexdigest("#{url}|#{attempt}")[0...10]
    end
    
    # Convert to URL-safe Base64 and trim to desired length
    key_length = use_long_key ? LONG_KEY_LENGTH : SHORT_KEY_LENGTH
    key = Base64.urlsafe_encode64(digest).gsub(/=+$/, '')[0...key_length]
    
    # Handle collisions
    if exists?(shortened_key: key)
      encode(url, attempt + 1, use_long_key, depth + 1)
    else
      key
    end
  end

  # Retrieves the original URL from a shortened key
  # 
  # @param key [String] the shortened key to decode
  # @return [String, nil] the original URL or nil if not found
  def self.decode(key)
    find_by(shortened_key: key)&.original_url
  end

  #=============================
  # Public Instance Methods
  #=============================
  
  # Returns the full shortened URL including the domain
  # 
  # @return [String] the complete shortened URL
  def short_url
    domain = ENV['HOST_DOMAIN']
    
    if domain.blank?
      Rails.logger.warn "HOST_DOMAIN environment variable is not set. Using localhost:3000 as fallback."
      domain = "http://localhost:3000"
    end
    
    "#{domain}/#{shortened_key}"
  end

  #=============================
  # Private Methods
  #=============================
  private

  # Generates a shortened key using a multi-stage collision avoidance strategy:
  # 1. Try short keys (6 chars) with multiple attempts
  # 2. If still colliding, try long keys (8 chars) with multiple attempts
  # 3. If still colliding, generate a completely random key
  def generate_shortened_key
    return unless original_url.present?
    
    # Cache the collision check queries to reduce database hits
    # TODO: Consider using a more efficient caching strategy when database is large
    existing_keys = self.class.where(
      "LENGTH(shortened_key) = ? OR LENGTH(shortened_key) = ?", 
      SHORT_KEY_LENGTH, LONG_KEY_LENGTH
    ).pluck(:shortened_key).to_set
    
    # Stage 1: Short keys
    self.shortened_key = try_encode_with_attempts(original_url, 0, false, existing_keys)
    
    # Stage 2: Long keys (if needed)
    if existing_keys.include?(shortened_key)
      self.shortened_key = try_encode_with_attempts(original_url, 0, true, existing_keys)
    end
    
    # Stage 3: Random keys (final fallback)
    if existing_keys.include?(shortened_key)
      self.shortened_key = generate_random_key(existing_keys)
    end
  end
  
  # Tries encoding with multiple attempts before giving up on a strategy
  # 
  # @param url [String] the URL to encode
  # @param initial_attempt [Integer] the first attempt number to try
  # @param use_long_key [Boolean] whether to use the longer key format
  # @param existing_keys [Set] cached set of existing keys for collision checks
  # @return [String] the encoded key, or the last attempt if all collide
  def try_encode_with_attempts(url, initial_attempt, use_long_key, existing_keys)
    attempt = initial_attempt
    key = nil
    
    MAX_ATTEMPTS.times do
      key = self.class.encode(url, attempt, use_long_key)
      break unless existing_keys.include?(key)
      attempt += 1
    end
    
    key
  end
  
  # Generates a guaranteed unique random key as a last resort
  # 
  # @param existing_keys [Set] cached set of existing keys for collision checks
  # @return [String] a unique random key
  def generate_random_key(existing_keys = nil)
    if existing_keys.nil?
      # If no cached keys are provided, use database queries
      # TODO: Safety break to prevent infinite loop if database is large
      #       Should have timeout or max attempts
      loop do
        random_key = SecureRandom.urlsafe_base64(6).gsub(/=+$/, '')[0...LONG_KEY_LENGTH]
        return random_key unless self.class.exists?(shortened_key: random_key)
      end
    else
      # Use the cached set to avoid database queries
      MAX_ATTEMPTS.times do
        random_key = SecureRandom.urlsafe_base64(6).gsub(/=+$/, '')[0...LONG_KEY_LENGTH]
        return random_key unless existing_keys.include?(random_key)
      end
      
      # If we still have collisions, ensure uniqueness with a timestamp
      "#{SecureRandom.urlsafe_base64(4).gsub(/=+$/, '')}_#{Time.now.to_i.to_s(36)}"[0...LONG_KEY_LENGTH]
    end
  end
end
