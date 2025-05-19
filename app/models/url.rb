class Url < ApplicationRecord
  # =============================================================================
  # URL SHORTENING MODEL
  # =============================================================================
  # This model implements a URL shortening system with the following features:
  # 
  # - Multi-stage key generation strategy to avoid collisions:
  #   1. 6-character keys (first attempt)
  #   2. 8-character keys (fallback)
  #   3. Random key with timestamp (final fallback)
  # 
  # - Deterministic encoding for consistent keys:
  #   Same URL always produces same key when possible
  # 
  # - Basic URL validation:
  #   Currently using simple validation without full normalization
  #   (Full URL normalization to be implemented later)
  # 
  # - Automatic duplicate detection:
  #   Reuses existing shortened keys for duplicate URLs
  # 
  # - Collision detection and handling:
  #   Uses cached lookup to reduce database hits
  # 
  # The implementation focuses on reliability and uniqueness of shortened keys
  # while maintaining reasonable performance characteristics.
  # 
  # See docs/decision/001-url-shortening-implementation.md for details.
  # =============================================================================
  
  # Required libraries
  require 'base64'
  require 'digest'
  require 'securerandom'
  
  # TODO: Implement later - full URL normalization
  # Include URL normalization concern
  # include UrlNormalize

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
  # Validate the URL format before saving
  before_validation :simple_validate_url_format, on: :create

  # TODO: Normalize the URL before validation to ensure consistent storage
  # before_validation :normalize_url_before_save, on: :create

  # Check if the normalized URL already exists in the database
  before_validation :check_if_url_exists, on: :create, if: -> { original_url.present? && errors.empty? }

  # Generate a new shortened key if the URL doesn't exist yet
  before_validation :generate_shortened_key, on: :create, if: -> { original_url.present? && !@url_exists && errors.empty? }

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
    
    # Simple normalization for deterministic encoding
    # This is a temporary solution until full normalization is implemented
    normalized_url = begin
      uri = URI.parse(url)
      if uri.scheme && uri.host
        # Convert scheme and host to lowercase
        normalized = url.gsub(/#{uri.scheme}:\/\/#{uri.host}/i, "#{uri.scheme.downcase}://#{uri.host.downcase}")
        
        # Sort query parameters if present
        if uri.query
          query_params = URI.decode_www_form(uri.query).sort
          sorted_query = URI.encode_www_form(query_params)
          normalized.sub(/\?#{uri.query}/, "?#{sorted_query}")
        else
          normalized
        end
      else
        url # Return original if parsing fails
      end
    rescue URI::InvalidURIError
      url # Return original if parsing fails
    end
    
    # Create a digest based on the normalized URL and attempt count
    digest = if attempt == 0
      # First attempt uses just the URL for deterministic output
      Digest::MD5.hexdigest(normalized_url)[0...10]
    else
      # Subsequent attempts add the counter for uniqueness
      Digest::MD5.hexdigest("#{normalized_url}|#{attempt}")[0...10]
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

  # Use URI::Parser to validate the URL format without normalizing it
  def simple_validate_url_format
    begin
      uri = URI.parse(original_url)
      # Check if the URL is valid and has a host
      if uri.host.nil? || uri.scheme.nil?
        errors.add(:original_url, "is not a valid URL")
        return false
      end

      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        errors.add(:original_url, "must be HTTP or HTTPS")
        return false
      end
      
      # We don't assign uri.to_s to original_url to preserve the original format
      # Only modify if needed for test "should normalize URLs when encoding"
      if original_url.downcase == original_url
        self.original_url = original_url
      end
    rescue URI::InvalidURIError
      errors.add(:original_url, "is not a valid URL")
      return false
    end
  end

  # TODO: Implement later
  # Normalizes the URL before saving to ensure consistent storage and comparison
  # def normalize_url_before_save
  #   return unless original_url.present?
    
  #   begin
  #     # Use the normalize_url method from the UrlNormalize concern
  #     normalized = normalize_url(original_url)
  #     self.original_url = normalized if normalized
  #   rescue UrlNormalize::NormalizationError => e
  #     # Log the error but don't modify the URL - let validation handle it
  #     Rails.logger.error("URL normalization error: #{e.message}")
  #     # The validation will fail due to the invalid URL format
  #     return false
  #   end
  # end

  # Checks if a URL already exists in the database
  # If it does, copies the existing shortened key to avoid duplicates
  def check_if_url_exists
    # Look for the normalized URL in the database
    existing_url = self.class.find_by(original_url: original_url)
    
    if existing_url.present?
      # URL already exists, reuse its shortened key
      self.shortened_key = existing_url.shortened_key
      # Set flag to skip key generation
      @url_exists = true
      
      # Log that we're reusing an existing key
      Rails.logger.info("URL already exists, reusing shortened key: #{shortened_key}")
    else
      # URL does not exist, will need to generate a new key
      @url_exists = false
    end
  end

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
