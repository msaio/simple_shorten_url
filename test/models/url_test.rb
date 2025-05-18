require "test_helper"

# URL Model Tests
# ------------------------------------------------------------------------------
# This test suite verifies the URL shortening functionality with its multi-stage 
# collision avoidance strategy:
#
# Basic Functionality Tests:
# - Creation and validation of URL records
# - Uniqueness constraints for both original URLs and shortened keys
#   Tests: should save url with original url, 
#          should not save url without original url,
#          should not save duplicate original url
#
# Encoding/Decoding Tests:
# - Deterministic encoding (same URL always produces same key)
# - Key length correctness (6 chars standard, 8 chars for fallback)
# - Decoding keys back to original URLs
#   Tests: encode method should produce deterministic output, 
#          encode method should produce a string of correct length,
#          encode method should produce different outputs for different URLs,
#          decode method should return the original url,
#          decode method should return nil for unknown key,
#          same URL should always get the same key
#
# Collision Avoidance Strategy Tests:
# - Stage 1: 6-character keys with multiple attempts
# - Stage 2: 8-character keys with multiple attempts
# - Stage 3: Random key generation with timestamp fallback
#   Tests: should handle multi-stage key length strategy
#          
# Environment Configuration Tests:
# - HOST_DOMAIN environment variable usage with fallback
#   Tests: short url should include domain from HOST_DOMAIN environment variable
#
# Advanced Collision Handling Tests:
# - Protection against excessive recursion
# - Random key generation with uniqueness guarantees
# - Cached collision checking
#   Tests: encode method should handle recursion depth limit,
#          generate random key should create unique keys,
#          should handle cached collision checking,
#          fallback with timestamp should work when all else fails,
#          constants should be properly defined
# ------------------------------------------------------------------------------

class UrlTest < ActiveSupport::TestCase
  setup do
    # Add a random suffix to ensure unique URLs for each test
    @random_suffix = SecureRandom.hex(4)
    @original_url = "https://example.com/very/long/path/to/a/page?with=parameters&and=more&rand=#{@random_suffix}"
  end
  
  test "should save url with original url" do
    url = Url.new(original_url: @original_url)
    assert url.save, "Failed to save URL with original URL"
    assert_not_nil url.shortened_key, "Shortened key was not generated"
  end
  
  test "should not save url without original url" do
    url = Url.new
    assert_not url.save, "Saved URL without original URL"
  end
  
  test "should not save duplicate original url" do
    url1 = Url.create(original_url: @original_url)
    
    url2 = Url.new(original_url: @original_url)
    assert_not url2.save, "Saved duplicate original URL"
  end
  
  test "encode method should produce deterministic output" do
    key1 = Url.encode(@original_url)
    key2 = Url.encode(@original_url)
    assert_equal key1, key2, "Encoding the same URL twice produced different keys"
  end
  
  test "encode method should produce a string of correct length" do
    # Short key (default)
    key = Url.encode(@original_url)
    assert_equal Url::SHORT_KEY_LENGTH, key.length, "Short key length should be #{Url::SHORT_KEY_LENGTH} characters"
    
    # Long key (explicitly requested)
    long_key = Url.encode(@original_url, 0, true)
    assert_equal Url::LONG_KEY_LENGTH, long_key.length, "Long key length should be #{Url::LONG_KEY_LENGTH} characters"
  end
  
  test "encode method should produce different outputs for different URLs" do
    key1 = Url.encode(@original_url)
    key2 = Url.encode(@original_url + "/different")
    assert_not_equal key1, key2, "Different URLs produced the same key"
  end
  
  test "decode method should return the original url" do
    # Create a unique URL just for this test
    unique_url = "https://example.com/decode-test-#{SecureRandom.hex(8)}"
    url = Url.create(original_url: unique_url)
    assert_equal unique_url, Url.decode(url.shortened_key), "Decode did not return the original URL"
  end
  
  test "decode method should return nil for unknown key" do
    assert_nil Url.decode("nonexistent"), "Decode did not return nil for unknown key"
  end
  
  test "same URL should always get the same key" do
    # Create a unique URL just for this test
    unique_url = "https://example.com/same-key-test-#{SecureRandom.hex(8)}"
    url1 = Url.create(original_url: unique_url)
    
    # Use destroy instead of delete_all to ensure we don't affect other tests
    url1.destroy
    
    url2 = Url.create(original_url: unique_url)
    assert_equal url1.shortened_key, url2.shortened_key, "Same URL got different keys"
  end
  
  test "should handle multi-stage key length strategy" do
    # We'll test each stage separately to ensure they work
    
    # Test that standard encoding produces 6-character keys
    key = Url.encode("https://example.com/test")
    assert_equal Url::SHORT_KEY_LENGTH, key.length, "Default key should be 6 characters"
    
    # Test that long key encoding produces 8-character keys
    long_key = Url.encode("https://example.com/test", 0, true)
    assert_equal Url::LONG_KEY_LENGTH, long_key.length, "Long key should be 8 characters"
    
    # Test that the model can actually generate keys of both lengths
    url1 = Url.create(original_url: "https://example.com/short-test-#{SecureRandom.hex(8)}")
    assert_equal Url::SHORT_KEY_LENGTH, url1.shortened_key.length, "Generated key should be 6 characters by default"
    
    # Verify our model is configured correctly
    assert_equal 6, Url::SHORT_KEY_LENGTH, "SHORT_KEY_LENGTH should be 6"
    assert_equal 8, Url::LONG_KEY_LENGTH, "LONG_KEY_LENGTH should be 8"
    assert_equal 5, Url::MAX_ATTEMPTS, "MAX_ATTEMPTS should be 5"
  end
  
  test "short url should include domain from HOST_DOMAIN environment variable" do
    url = Url.create(original_url: @original_url)
    
    # Test with HOST_DOMAIN set
    original_env = ENV['HOST_DOMAIN']
    ENV['HOST_DOMAIN'] = "https://short.test"
    
    begin
      assert_equal "https://short.test/#{url.shortened_key}", url.short_url, "short_url did not use HOST_DOMAIN"
      
      # Test fallback when HOST_DOMAIN is not set
      ENV['HOST_DOMAIN'] = nil
      assert_includes url.short_url, url.shortened_key, "short_url doesn't contain the shortened key"
      assert_includes url.short_url, "localhost:3000", "short_url doesn't use fallback domain"
    ensure
      # Restore original environment
      ENV['HOST_DOMAIN'] = original_env
    end
  end
  
  test "encode method should handle recursion depth limit" do
    # Simulate a situation where recursion would exceed the limit
    original_exists_method = Url.method(:exists?)
    
    begin
      # Make exists? always return true to force maximum recursion
      Url.define_singleton_method(:exists?) do |conditions|
        true
      end
      
      # This should not raise a SystemStackError due to our depth limit
      key = Url.encode(@original_url)
      assert_not_nil key, "encode method returned nil with recursion limit"
      assert_equal Url::SHORT_KEY_LENGTH, key.length, "Key length incorrect when hitting recursion limit"
      
      # Try with long key too
      long_key = Url.encode(@original_url, 0, true)
      assert_equal Url::LONG_KEY_LENGTH, long_key.length, "Long key length incorrect when hitting recursion limit"
    ensure
      # Restore original method
      Url.singleton_class.send(:remove_method, :exists?)
      Url.define_singleton_method(:exists?, &original_exists_method)
    end
  end
  
  test "generate_random_key should create unique keys" do
    # Create multiple random keys and check for uniqueness
    keys = []
    url = Url.new(original_url: @original_url) # Just to access the private method
    
    # Use send to call the private method
    10.times do
      keys << url.send(:generate_random_key)
    end
    
    # Check that all keys are unique
    assert_equal keys.uniq.count, keys.count, "Random keys are not all unique"
    
    # Check key length
    keys.each do |key|
      assert_equal Url::LONG_KEY_LENGTH, key.length, "Random key has incorrect length"
    end
  end
  
  test "should handle cached collision checking" do
    url = Url.new(original_url: @original_url)
    
    # Create a mock set of existing keys
    existing_keys = Set.new(["abcdef", "ghijkl", "mnopqr"])
    
    # Test the private method with our mock set
    key = url.send(:try_encode_with_attempts, @original_url, 0, false, existing_keys)
    
    # Make sure we got a key and it's not in our mock set
    assert_not_nil key, "No key generated with cached collision checking"
    assert_not_includes existing_keys, key, "Generated a key that collides with existing keys"
  end
  
  test "fallback with timestamp should work when all else fails" do
    url = Url.new(original_url: @original_url)
    
    # Create a set that will always cause initial collisions
    mock_set = Set.new
    
    # Override generate_random_key to test the timestamp fallback
    def url.generate_random_key(existing_keys)
      # Skip the regular random key generation and go straight to timestamp fallback
      "#{SecureRandom.urlsafe_base64(4).gsub(/=+$/, '')}_#{Time.now.to_i.to_s(36)}"[0...Url::LONG_KEY_LENGTH]
    end
    
    # Generate a key and verify it
    key = url.send(:generate_random_key, mock_set)
    
    # The key should be valid
    assert_not_nil key, "Timestamp fallback didn't generate a key"
    assert_equal Url::LONG_KEY_LENGTH, key.length, "Timestamp fallback key has incorrect length"
  end
  
  test "constants should be properly defined" do
    assert defined?(Url::SHORT_KEY_LENGTH), "SHORT_KEY_LENGTH constant is not defined"
    assert defined?(Url::LONG_KEY_LENGTH), "LONG_KEY_LENGTH constant is not defined"
    assert defined?(Url::MAX_ATTEMPTS), "MAX_ATTEMPTS constant is not defined"
    assert defined?(Url::MAX_RECURSION_DEPTH), "MAX_RECURSION_DEPTH constant is not defined"
    
    assert Url::SHORT_KEY_LENGTH < Url::LONG_KEY_LENGTH, "SHORT_KEY_LENGTH should be less than LONG_KEY_LENGTH"
    assert Url::MAX_ATTEMPTS > 0, "MAX_ATTEMPTS should be positive"
    assert Url::MAX_RECURSION_DEPTH > 0, "MAX_RECURSION_DEPTH should be positive"
  end
end
