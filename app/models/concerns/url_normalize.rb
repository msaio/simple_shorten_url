module UrlNormalize
  # TODO: Enhance this concern later

  # =============================================================================
  # URL NORMALIZATION CONCERN
  # =============================================================================
  # This concern implements URL normalization to ensure consistent URL storage
  # and accurate duplicate detection with the following features:
  # 
  # - Format standardization:
  #   1. Adding http:// scheme if missing
  #   2. Converting scheme and host to lowercase
  #   3. Removing default ports (80 for HTTP, 443 for HTTPS)
  #   4. Removing 'www.' subdomain prefix
  # 
  # - Parameter handling:
  #   1. Sorting query parameters alphabetically
  #   2. Removing empty query strings and fragments
  #   3. Removing trailing slashes from root paths
  # 
  # - Error handling:
  #   Custom exception hierarchy for different error conditions
  #   (empty URLs, missing hosts, invalid format, unsupported schemes)
  # 
  # Currently only HTTP and HTTPS schemes are supported.
  # See docs/decision/001-url-shortening-implementation.md for details.
  # =============================================================================
  
  extend ActiveSupport::Concern
  
  # Custom exception classes for URL normalization errors
  class NormalizationError < StandardError; end
  class EmptyUrlError < NormalizationError; end
  class InvalidUrlError < NormalizationError; end
  class UnsupportedSchemeError < NormalizationError; end
  class MissingHostError < NormalizationError; end

  included do
    # Normalizes the URL to ensure consistent storage and comparison across URLs
    # This process helps eliminate duplicate URLs that are technically the same but formatted differently
    # 
    # @param original_url [String] the URL to normalize
    # @return [String] the normalized URL
    # @raise [EmptyUrlError] if the URL is nil or empty
    # @raise [MissingHostError] if the URL doesn't contain a host
    # @raise [UnsupportedSchemeError] if the URL uses a non-HTTP/HTTPS scheme
    # @raise [InvalidUrlError] if the URL is malformed or invalid
    def normalize_url(original_url)
      if original_url.blank?
        error_message = "URL cannot be nil or empty"
        Rails.logger.error(error_message) if defined?(Rails)
        errors.add(:original_url, error_message) if respond_to?(:errors)
        raise EmptyUrlError, error_message
      end
      
      # Strip whitespace before parsing
      url_to_normalize = original_url.strip
      
      begin
        # Convert scheme to lowercase before adding scheme or parsing
        # This ensures proper handling of uppercase schemes like HTTP:// or HTTPS://
        if url_to_normalize =~ /^([A-Za-z]+):\/\//
          scheme = $1.downcase
          url_to_normalize = "#{scheme}://#{url_to_normalize.sub(/^[A-Za-z]+:\/\//, '')}"
        end
        
        # Add http:// prefix if no scheme is present
        if !url_to_normalize.match?(/^[a-z]+:\/\//)
          url_to_normalize = "http://#{url_to_normalize}"
        end
        
        # Parse the URL
        uri = URI.parse(url_to_normalize)
        
        # Check for missing host
        if uri.host.blank?
          error_message = "URL must contain a host"
          Rails.logger.error(error_message) if defined?(Rails)
          errors.add(:original_url, error_message) if respond_to?(:errors)
          raise MissingHostError, error_message
        end
        
        # Check if scheme is supported (currently only http and https)
        if uri.scheme && !['http', 'https'].include?(uri.scheme.downcase)
          error_message = "Unsupported URL scheme: #{uri.scheme}. Currently only HTTP and HTTPS are supported."
          Rails.logger.error(error_message) if defined?(Rails)
          errors.add(:original_url, "has unsupported scheme (#{uri.scheme}). Only HTTP and HTTPS are supported.") if respond_to?(:errors)
          raise UnsupportedSchemeError, error_message
        end
        
        # Force lowercase for scheme and host
        uri.scheme = uri.scheme.downcase if uri.scheme
        uri.host = uri.host.downcase if uri.host
        
        # Remove default ports (80 for http, 443 for https)
        if (uri.scheme == 'http' && uri.port == 80) || 
          (uri.scheme == 'https' && uri.port == 443)
          uri.port = nil
        end
        
        # Remove www. prefix from hostname
        uri.host = uri.host.sub(/^www\./, '') if uri.host
        
        # Sort query parameters if present for consistent storage
        if uri.query
          require 'rack'
          query_hash = Rack::Utils.parse_nested_query(uri.query)
          
          if query_hash.any?
            # Sort by keys and rebuild
            sorted_query = query_hash.sort.to_h
            uri.query = Rack::Utils.build_nested_query(sorted_query)
          else
            # Remove empty query string
            uri.query = nil
          end
        end
        
        # Remove trailing slash from path if it's the only path character
        if uri.path == '/'
          uri.path = ''
        end
        
        # Remove empty fragments
        uri.fragment = nil if uri.fragment == '' || uri.fragment.nil?
        
        # Return the normalized URL as a string
        normalized_url = uri.to_s

      rescue URI::InvalidURIError => e
        error_message = "Invalid URL format: #{e.message}"
        Rails.logger.error("Invalid URL normalization attempt: #{url_to_normalize}, Error: #{e.message}") if defined?(Rails)
        errors.add(:original_url, "is not a valid URL format") if respond_to?(:errors)
        raise InvalidUrlError, error_message
      end
    end
  end
end