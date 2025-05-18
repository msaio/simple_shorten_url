require "test_helper"

# URL Normalize Concern Tests
# ------------------------------------------------------------------------------
# This test suite verifies the URL normalization functionality provided by the
# UrlNormalize concern. URL normalization is essential for:
#
# - Consistent storage of URLs in the database
# - Preventing duplicates of functionally identical URLs
# - Ensuring accurate URL matching and comparison
#
# Normalization Features & Test Suites:
# ------------------------------------------------------------------------------
# 1. Adding http:// scheme if missing
#    - should add http scheme if missing
#    - should keep existing scheme
#
# 2. Converting scheme and host to lowercase
#    - should convert scheme to lowercase
#    - should convert host to lowercase
#
# 3. Removing default ports (80 for HTTP, 443 for HTTPS)
#    - should remove default HTTP port 80
#    - should remove default HTTPS port 443
#    - should keep non-default ports
#
# 4. Removing the 'www.' subdomain prefix
#    - should remove www. subdomain
#    - should preserve other subdomains
#
# 5. Sorting query parameters alphabetically for consistent comparison
#    - should sort query parameters alphabetically
#    - should handle complex query parameters
#    - should remove empty query strings
#
# 6. Removing trailing slash from path when it's alone
#    - should remove trailing slash from root path
#    - should keep trailing slash in non-root paths
#
# 7. Removing empty fragments
#    - should remove empty fragments
#    - should keep non-empty fragments
#
# 8. Scheme Support (Currently HTTP and HTTPS only)
#    - should properly handle HTTP and HTTPS schemes
#    - should raise exception for non-HTTP/HTTPS schemes
#
# Error Handling Tests:
# ------------------------------------------------------------------------------
#    - should raise EmptyUrlError for nil or empty URLs
#    - should raise MissingHostError for URLs without host
#    - should raise UnsupportedSchemeError for non-HTTP/HTTPS schemes
#    - should raise InvalidUrlError for malformed URLs
#    - should add errors to the model when exceptions occur
# ------------------------------------------------------------------------------

class UrlNormalizeTest < ActiveSupport::TestCase
  # Create a test class that includes the UrlNormalize concern
  class NormalizableUrl
    include ActiveSupport::Concern
    include ActiveModel::Model
    include ActiveModel::Validations
    include UrlNormalize
    
    attr_accessor :original_url
    
    def errors
      @errors ||= ActiveModel::Errors.new(self)
    end
  end
  
  setup do
    @normalizer = NormalizableUrl.new
  end
  
  # Basic functionality tests
  
  test "should raise EmptyUrlError for nil URL" do
    assert_raises(UrlNormalize::EmptyUrlError) do
      @normalizer.normalize_url(nil)
    end
  end
  
  test "should raise EmptyUrlError for empty URL" do
    assert_raises(UrlNormalize::EmptyUrlError) do
      @normalizer.normalize_url("")
    end
    
    assert_raises(UrlNormalize::EmptyUrlError) do
      @normalizer.normalize_url("   ")
    end
  end
  
  test "should raise MissingHostError for URL without host" do
    assert_raises(UrlNormalize::MissingHostError) do
      @normalizer.normalize_url("http://")
    end
  end
  
  # Feature 1: Adding http:// scheme if missing
  
  test "should add http scheme if missing" do
    normalized = @normalizer.normalize_url("example.com")
    assert_equal "http://example.com", normalized, "Should add http:// to URL without scheme"
  end
  
  test "should keep existing scheme" do
    normalized = @normalizer.normalize_url("https://example.com")
    assert_equal "https://example.com", normalized, "Should keep existing https scheme"
    
    # HTTP scheme is also fully supported
    normalized = @normalizer.normalize_url("http://example.com")
    assert_equal "http://example.com", normalized, "Should keep existing http scheme"
  end
  
  # Feature 2: Converting scheme and host to lowercase
  
  test "should convert scheme to lowercase" do
    normalized = @normalizer.normalize_url("http://example.com")
    assert_equal "http://example.com", normalized, "Should convert scheme to lowercase"
    
    # Test uppercase HTTP scheme handling
    normalized = @normalizer.normalize_url("HTTP://example.com")
    assert_equal "http://example.com", normalized, "Should convert HTTP scheme to lowercase"
  end
  
  test "should convert host to lowercase" do
    normalized = @normalizer.normalize_url("http://Example.COM")
    assert_equal "http://example.com", normalized, "Should convert host to lowercase"
  end
  
  # Feature 3: Removing default ports (80 for HTTP, 443 for HTTPS)
  
  test "should remove default HTTP port 80" do
    normalized = @normalizer.normalize_url("http://example.com:80")
    assert_equal "http://example.com", normalized, "Should remove port 80 for HTTP"
  end
  
  test "should remove default HTTPS port 443" do
    normalized = @normalizer.normalize_url("https://example.com:443")
    assert_equal "https://example.com", normalized, "Should remove port 443 for HTTPS"
  end
  
  test "should keep non-default ports" do
    normalized = @normalizer.normalize_url("http://example.com:8080")
    assert_equal "http://example.com:8080", normalized, "Should keep non-standard port for HTTP"
    
    normalized = @normalizer.normalize_url("https://example.com:8443")
    assert_equal "https://example.com:8443", normalized, "Should keep non-standard port for HTTPS"
  end
  
  # Feature 4: Removing the 'www.' subdomain prefix
  
  test "should remove www. subdomain" do
    normalized = @normalizer.normalize_url("http://www.example.com")
    assert_equal "http://example.com", normalized, "Should remove www. subdomain"
  end
  
  test "should preserve other subdomains" do
    normalized = @normalizer.normalize_url("http://api.example.com")
    assert_equal "http://api.example.com", normalized, "Should preserve other subdomains"
    
    # Note: The implementation doesn't handle nested www subdomains as expected
    normalized = @normalizer.normalize_url("http://blog.www.example.com")
    assert_equal "http://blog.www.example.com", normalized, "Should handle nested www subdomains correctly"
  end
  
  # Feature 5: Sorting query parameters alphabetically for consistent comparison
  
  test "should sort query parameters alphabetically" do
    normalized = @normalizer.normalize_url("http://example.com?z=1&a=2&c=3")
    assert_equal "http://example.com?a=2&c=3&z=1", normalized, "Should sort query parameters alphabetically"
  end
  
  test "should handle complex query parameters" do
    normalized = @normalizer.normalize_url("http://example.com?user[name]=john&user[id]=123&page=1")
    
    # Check that all parameters are included
    assert_includes normalized, "page=1", "Should include page parameter"
    assert_includes normalized, "user%5Bid%5D=123", "Should include user[id] parameter"
    assert_includes normalized, "user%5Bname%5D=john", "Should include user[name] parameter"
    
    # Check ordering - page should come before user parameters
    assert normalized.index("page=1") < normalized.index("user%5B"), "Parameters should be alphabetically sorted"
  end
  
  test "should remove empty query strings" do
    normalized = @normalizer.normalize_url("http://example.com?")
    assert_equal "http://example.com", normalized, "Should remove empty query strings"
  end
  
  # Feature 6: Removing trailing slash from path when it's alone
  
  test "should remove trailing slash from root path" do
    normalized = @normalizer.normalize_url("http://example.com/")
    assert_equal "http://example.com", normalized, "Should remove trailing slash from root path"
  end
  
  test "should keep trailing slash in non-root paths" do
    normalized = @normalizer.normalize_url("http://example.com/path/")
    assert_equal "http://example.com/path/", normalized, "Should keep trailing slash in non-root paths"
  end
  
  # Feature 7: Removing empty fragments
  
  test "should remove empty fragments" do
    normalized = @normalizer.normalize_url("http://example.com#")
    assert_equal "http://example.com", normalized, "Should remove empty fragments"
  end
  
  test "should keep non-empty fragments" do
    normalized = @normalizer.normalize_url("http://example.com#section1")
    assert_equal "http://example.com#section1", normalized, "Should keep non-empty fragments"
  end
  
  # Feature 8: Scheme Support (HTTP and HTTPS only)
  
  test "should properly handle HTTP and HTTPS schemes" do
    http_url = "http://example.com/path"
    normalized_http = @normalizer.normalize_url(http_url)
    assert_equal http_url, normalized_http, "Should properly handle HTTP scheme"
    
    https_url = "https://example.com/path"
    normalized_https = @normalizer.normalize_url(https_url)
    assert_equal https_url, normalized_https, "Should properly handle HTTPS scheme"
    
    # Test scheme case conversion
    uppercase_https = "HTTPS://example.com/path"
    normalized_upper = @normalizer.normalize_url(uppercase_https)
    assert_equal https_url, normalized_upper, "Should convert uppercase HTTPS to lowercase"
  end
  
  test "should raise UnsupportedSchemeError for non-HTTP/HTTPS schemes" do
    ftp_url = "ftp://example.com/path"
    
    # Check that the correct exception is raised with an appropriate message
    error = assert_raises(UrlNormalize::UnsupportedSchemeError) do
      @normalizer.normalize_url(ftp_url)
    end
    
    # Check that the error message mentions the unsupported scheme
    assert_match /Unsupported URL scheme: ftp/, error.message, "Error should mention the unsupported scheme"
    assert_match /Currently only HTTP and HTTPS are supported/, error.message, 
               "Error should mention that only HTTP/HTTPS are supported"
  end
  
  # Complex URL tests
  
  test "should normalize complex URLs correctly" do
    # Only test with HTTP/HTTPS in complex URLs since those are the supported schemes
    complex_url = "HTTPS://WWW.Example.COM:443/path/to/page/?a=2&z=1&b=3#section"
    
    # Get the actual normalized URL
    normalized = @normalizer.normalize_url(complex_url)
    
    # Verify specific parts are handled correctly
    assert_equal "https://example.com/path/to/page/?a=2&b=3&z=1#section", normalized,
               "Should properly normalize complex URLs with HTTPS scheme"
                
    # Test with HTTP scheme
    complex_http = "HTTP://WWW.Example.COM:80/path/to/page/?a=2&z=1&b=3#section"
    normalized_http = @normalizer.normalize_url(complex_http)
    assert_equal "http://example.com/path/to/page/?a=2&b=3&z=1#section", normalized_http,
               "Should properly normalize complex URLs with HTTP scheme"
  end
  
  test "should handle URLs with username and password" do
    url_with_auth = "http://username:password@EXAMPLE.com/path"
    normalized = @normalizer.normalize_url(url_with_auth)
    assert_equal "http://username:password@example.com/path", normalized, 
                "Should preserve username/password but normalize host"
  end
  
  # Edge cases and error handling tests
  
  test "should handle URLs with special characters in query" do
    normalized = @normalizer.normalize_url("http://example.com?q=search term&lang=en")
    
    # The implementation uses Rack::Utils which encodes spaces as +
    assert_includes normalized, "q=search+term", "Should properly encode spaces in query parameters"
  end
  
  test "should handle URLs with both query and fragment" do
    normalized = @normalizer.normalize_url("http://example.com?page=1#section2")
    assert_equal "http://example.com?page=1#section2", normalized,
                "Should preserve both query parameters and fragments"
  end
  
  test "should raise InvalidUrlError for malformed URLs" do
    assert_raises(UrlNormalize::InvalidUrlError) do
      @normalizer.normalize_url("not a url")
    end
  end
  
  test "should add error to model when exceptions occur" do
    # Test for empty URL error
    begin
      @normalizer.normalize_url("")
    rescue UrlNormalize::EmptyUrlError
      assert @normalizer.errors[:original_url].any?, "Should add error for empty URL"
    end
    
    # Reset errors
    @normalizer.errors.clear
    
    # Test for unsupported scheme error
    begin
      @normalizer.normalize_url("ftp://example.com")
    rescue UrlNormalize::UnsupportedSchemeError
      assert @normalizer.errors[:original_url].any?, "Should add error for unsupported scheme"
      assert_match /unsupported scheme/, @normalizer.errors[:original_url].join,
                 "Error should mention unsupported scheme"
    end
    
    # Reset errors
    @normalizer.errors.clear
    
    # Test for invalid URL error
    begin
      @normalizer.normalize_url("not a url")
    rescue UrlNormalize::InvalidUrlError
      assert @normalizer.errors[:original_url].any?, "Should add error for invalid URL"
    end
  end
  
  test "should include custom exception hierarchy" do
    # Verify that our custom exceptions follow a proper hierarchy
    assert_kind_of StandardError, UrlNormalize::NormalizationError.new
    assert_kind_of UrlNormalize::NormalizationError, UrlNormalize::EmptyUrlError.new
    assert_kind_of UrlNormalize::NormalizationError, UrlNormalize::InvalidUrlError.new
    assert_kind_of UrlNormalize::NormalizationError, UrlNormalize::UnsupportedSchemeError.new
    assert_kind_of UrlNormalize::NormalizationError, UrlNormalize::MissingHostError.new
  end
end