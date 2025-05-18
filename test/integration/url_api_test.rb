require "test_helper"

# URL API Integration Tests
# ------------------------------------------------------------------------------
# This test suite verifies the URL shortening API endpoints functionality:
#
# Encode Endpoint Tests (/encode):
# - Basic request processing
# - URL parameter validation
# - Error handling for invalid URLs and normalization errors
# - Response format validation
# - URL normalization through the model
#   Tests: should encode a URL successfully, 
#          should return 400 when URL parameter is missing,
#          should handle invalid URLs properly,
#          should reuse existing shortened URLs,
#          should normalize URLs when encoding,
#          should handle normalization errors
#
# Decode Endpoint Tests (/decode):
# - Basic request processing
# - URL parameter validation
# - URL key extraction
# - Error handling for non-existent URLs
# - Response format validation
#   Tests: should decode a shortened URL successfully,
#          should return 400 when URL parameter is missing,
#          should return 404 for unknown URLs,
#          should correctly extract key from different URL formats
#
# Integration Tests:
# - Full encode-decode round-trip
#   Tests: should correctly round-trip a URL through encode and decode
# ------------------------------------------------------------------------------
class UrlApiTest < ActionDispatch::IntegrationTest
  setup do
    # Create a unique URL for testing
    @random_suffix = SecureRandom.hex(4)
    @test_url = "https://example.com/path/to/resource?param=#{@random_suffix}"
  end

  # === ENCODE ENDPOINT TESTS ===

  test "should encode a URL successfully" do
    post encode_url, params: { url: @test_url }, as: :json
    
    assert_response :success
    response_json = JSON.parse(response.body)
    assert response_json.key?("url"), "Response missing 'url' key"
    assert response_json["url"].present?, "Response has empty 'url' value"
    assert_match %r{https?://\S+/\w+}, response_json["url"], "Response URL does not match expected format"
  end

  test "should return 400 when URL parameter is missing" do
    post encode_url, params: {}, as: :json
    
    assert_response :bad_request
    response_json = JSON.parse(response.body)
    assert response_json.key?("error"), "Response missing 'error' key"
    assert_equal "Missing url parameter", response_json["error"]
  end

  test "should handle invalid URLs properly" do
    # Create a class for mocking
    original_method = Url.method(:create!)
    
    begin
      # Replace the create! method to raise an error for invalid URLs
      Url.define_singleton_method(:create!) do |*args|
        raise URI::InvalidURIError.new("Invalid URL format")
      end
      
      post encode_url, params: { url: "invalid!!url" }, as: :json
      assert_response :bad_request
      response_json = JSON.parse(response.body)
      assert response_json.key?("error"), "Response missing 'error' key"
      assert_includes response_json["error"], "Invalid URL format", "Error message does not mention URL format"
    ensure
      # Restore the original method
      Url.singleton_class.send(:remove_method, :create!)
      Url.define_singleton_method(:create!, &original_method)
    end
  end

  test "should reuse existing shortened URLs" do
    # First request - creates a new shortened URL
    post encode_url, params: { url: @test_url }, as: :json
    assert_response :success
    first_response = JSON.parse(response.body)

    # Second request with same URL - should return the same shortened URL
    post encode_url, params: { url: @test_url }, as: :json
    assert_response :success
    second_response = JSON.parse(response.body)

    assert_equal first_response["url"], second_response["url"], "Different shortened URLs returned for the same original URL"
  end

  test "should normalize URLs when encoding" do
    # Create two URLs that should normalize to the same URL
    url1 = "HTTP://Example.COM/path?b=2&a=1"
    url2 = "http://example.com/path?a=1&b=2"
    
    # First request with the first URL format
    post encode_url, params: { url: url1 }, as: :json
    assert_response :success
    first_response = JSON.parse(response.body)
    
    # Second request with a different format of the same URL
    post encode_url, params: { url: url2 }, as: :json
    assert_response :success
    second_response = JSON.parse(response.body)
    
    # Both should return the same shortened URL
    assert_equal first_response["url"], second_response["url"], "Different formats of the same URL resulted in different shortened URLs"
  end

  test "should handle normalization errors" do
    # Create a class for mocking
    original_method = Url.method(:create!)
    
    begin
      # Replace the create! method to raise an error
      Url.define_singleton_method(:create!) do |*args|
        raise UrlNormalize::NormalizationError.new("Invalid URL format")
      end
      
      post encode_url, params: { url: "http://example.com" }, as: :json
      
      assert_response :bad_request
      response_json = JSON.parse(response.body)
      assert response_json.key?("error"), "Response missing 'error' key"
      assert_includes response_json["error"], "Invalid URL format", "Error message does not mention URL format"
    ensure
      # Restore the original method
      Url.singleton_class.send(:remove_method, :create!)
      Url.define_singleton_method(:create!, &original_method)
    end
  end

  # === DECODE ENDPOINT TESTS ===

  test "should decode a shortened URL successfully" do
    # First encode a URL
    post encode_url, params: { url: @test_url }, as: :json
    assert_response :success
    encoded_url = JSON.parse(response.body)["url"]

    # Then decode it
    post decode_url, params: { url: encoded_url }, as: :json
    assert_response :success
    
    response_json = JSON.parse(response.body)
    assert response_json.key?("url"), "Response missing 'url' key"
    assert_equal @test_url, response_json["url"], "Decoded URL does not match original"
  end

  test "should return 400 when URL parameter is missing for decode" do
    post decode_url, params: {}, as: :json
    
    assert_response :bad_request
    response_json = JSON.parse(response.body)
    assert response_json.key?("error"), "Response missing 'error' key"
    assert_equal "Missing url parameter", response_json["error"]
  end

  test "should return 404 for unknown URLs" do
    post decode_url, params: { url: "http://localhost:3000/nonexistent" }, as: :json
    
    assert_response :not_found
    response_json = JSON.parse(response.body)
    assert response_json.key?("error"), "Response missing 'error' key"
    assert_equal "URL not found", response_json["error"]
  end

  test "should correctly extract key from different URL formats" do
    # Create a URL record for testing
    url = Url.create!(original_url: @test_url)
    key = url.shortened_key
    
    # Test different formats of the shortened URL
    formats = [
      "http://example.com/#{key}",
      "https://example.com/#{key}",
      "http://localhost:3000/#{key}",
      "#{key}",                         # Just the key
      "/#{key}"                         # Path only
    ]
    
    formats.each do |format|
      post decode_url, params: { url: format }, as: :json
      
      assert_response :success, "Failed to decode URL format: #{format}"
      response_json = JSON.parse(response.body)
      assert_equal @test_url, response_json["url"], "Decoded URL does not match for format: #{format}"
    end
  end

  # === INTEGRATION TESTS ===

  test "should correctly round-trip a URL through encode and decode" do
    # Generate a unique URL to avoid conflicts
    unique_url = "https://example.com/round-trip-test-#{SecureRandom.hex(8)}"
    
    # Encode the URL
    post encode_url, params: { url: unique_url }, as: :json
    assert_response :success
    shortened_url = JSON.parse(response.body)["url"]
    
    # Decode the shortened URL
    post decode_url, params: { url: shortened_url }, as: :json
    assert_response :success
    decoded_url = JSON.parse(response.body)["url"]
    
    # Verify the round-trip
    assert_equal unique_url, decoded_url, "URL changed during encode-decode round-trip"
  end
end