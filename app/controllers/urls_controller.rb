class UrlsController < ApplicationController
  # =============================================================================
  # URL SHORTENING CONTROLLER
  # =============================================================================
  # This controller implements the URL shortening API endpoints:
  # 
  # - POST /encode: Converts a long URL to a shortened version
  #   Request: { url: <original_url> }
  #   Response: { url: <shortened_url> }
  #   The controller delegates to the URL model for:
  #     - URL normalization
  #     - Validation
  #     - Duplicate detection
  #     - Shortened key generation
  #
  # - POST /decode: Converts a shortened URL back to its original form
  #   Request: { url: <shortened_url> }
  #   Response: { url: <original_url> }
  #   Uses the model's decode method after extracting the key from the URL.
  # 
  # Error handling is implemented for common cases:
  # - Missing URL parameter
  # - Invalid URL format (via UrlNormalize::NormalizationError)
  # - URL not found in database
  # - Validation errors from the model
  # =============================================================================
  
  # Skip CSRF token verification for API endpoints
  skip_before_action :verify_authenticity_token, only: [:encode, :decode]

  # POST /encode
  # Converts a long URL to a shortened version
  def encode
    # Check if URL parameter exists
    unless params[:url].present?
      render json: { error: "Missing url parameter" }, status: :bad_request
      return
    end

    begin
      # The URL model will handle normalization, validation, and checking for duplicates
      # Simply attempt to create the record and let the model callbacks do their work
      url_record = Url.create!(original_url: params[:url])

      # Return the shortened URL
      render json: { url: url_record.short_url }, status: :ok
    rescue UrlNormalize::NormalizationError => e
      # Handle URL normalization errors
      render json: { error: e.message }, status: :bad_request
    rescue URI::InvalidURIError => e
      # Handle invalid URL format
      render json: { error: "Invalid URL format: #{e.message}" }, status: :bad_request
    rescue ActiveRecord::RecordInvalid => e
      # This will catch duplicate URLs and return the existing one
      if e.record.errors[:original_url]&.include?("has already been taken")
        # Find the existing record and return it
        url_record = Url.find_by(original_url: e.record.original_url)
        render json: { url: url_record.short_url }, status: :ok
      else
        # Other validation errors
        render json: { error: e.message }, status: :bad_request
      end
    rescue => e
      # Handle other unexpected errors
      render json: { error: "Error encoding URL: #{e.message}" }, status: :internal_server_error
    end
  end

  # POST /decode
  # Converts a shortened URL back to its original form
  def decode
    # Check if URL parameter exists
    unless params[:url].present?
      render json: { error: "Missing url parameter" }, status: :bad_request
      return
    end

    begin
      # Extract the key from the URL
      shortened_key = extract_key_from_url(params[:url])
      
      # Use the model's decode method to find the original URL
      original_url = Url.decode(shortened_key)
      
      if original_url.nil?
        render json: { error: "URL not found" }, status: :not_found
        return
      end

      # Return the original URL
      render json: { url: original_url }, status: :ok
    rescue URI::InvalidURIError => e
      # Handle invalid URL format
      render json: { error: "Invalid URL format: #{e.message}" }, status: :bad_request
    rescue => e
      # Handle unexpected errors
      render json: { error: "Error decoding URL: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  # Extracts the shortened key from a URL
  #
  # @param url [String] the shortened URL (e.g. "http://domain.com/abc123")
  # @return [String] the key part of the URL (e.g. "abc123")
  def extract_key_from_url(url)
    begin
      # Try to parse as URI
      uri = URI.parse(url)
      # Get the last part of the path
      path = uri.path.split("/").last
      return path if path.present?
      
      # If no path is found, try to parse from the raw string
      # This handles cases where the URL might not have scheme
      url.split("/").last
    rescue URI::InvalidURIError
      # If URI parsing fails, try to extract using regex
      if url =~ /\/([^\/]+)$/
        $1
      else
        # If all else fails, return the URL as is (might be just the key)
        url
      end
    end
  end
end