# URL Shortening Implementation

## Status

Implemented

## Context

The core functionality of our application is to shorten URLs. This document outlines the current implementation details of the URL shortening system.

## Implementation Details

The URL shortening system consists of the following components:

1. **URL Model**: Stores original URLs and their shortened keys
2. **URL Normalization**: Process for standardizing URLs before storage

### URL Model

The `Url` model has the following structure:

- **Constants**:
  - `SHORT_KEY_LENGTH = 6` - Standard key length
  - `LONG_KEY_LENGTH = 8` - Extended key length for collision handling
  - `MAX_ATTEMPTS = 5` - Maximum attempts per strategy
  - `MAX_RECURSION_DEPTH = 10` - Recursion depth limit for encoding

- **Validations**:
  - Presence and uniqueness of `original_url`
  - Presence and uniqueness of `shortened_key`

- **Callbacks**:
  - `before_validation :normalize_url_before_save` - Normalizes URLs before saving
  - `before_validation :check_if_url_exists` - Checks if URL already exists and reuses the key if it does
  - `before_validation :generate_shortened_key` - Generates a shortened key if needed

- **Key methods**:
  - `self.encode` - Converts a URL into a shortened key
  - `self.decode` - Retrieves the original URL from a key
  - `short_url` - Returns the full shortened URL with domain
  - `normalize_url_before_save` - Private method to normalize URLs before saving
  - `check_if_url_exists` - Private method to check for and handle existing URLs
  - `generate_shortened_key` - Private method implementing the key generation strategy

### Duplicate URL Handling

The system efficiently handles duplicate URLs:

1. URLs are first normalized to ensure consistent format
2. The system checks if the normalized URL already exists in the database
3. If the URL exists, the existing shortened key is reused rather than creating a new one
4. This reduces database size and ensures the same URL always gets the same shortened key

### Key Generation Strategy

The model employs a multi-stage key generation approach:

1. **Stage 1**: Short keys (6 characters)
   - MD5 hash of URL converted to URL-safe Base64
   - Multiple attempts with counter for collision handling

2. **Stage 2**: Long keys (8 characters)
   - Same algorithm with longer output length
   - Used if Stage 1 has collisions

3. **Stage 3**: Random key generation
   - SecureRandom-based keys as final fallback
   - Timestamp-based uniqueness guarantee

### URL Normalization

URL normalization is implemented through the `UrlNormalize` concern and is integrated with the URL model:

1. **Format standardization**:
   - Add `http://` scheme if missing
   - Convert scheme and host to lowercase
   - Remove default ports (80 for HTTP, 443 for HTTPS)
   - Remove `www.` subdomain prefix

2. **Parameter handling**:
   - Sort query parameters alphabetically
   - Remove empty query strings and fragments
   - Remove trailing slashes from root paths

3. **Error handling**:
   - Custom exception classes for different normalization errors
   - Validation error messages for invalid URLs

### Environment Configuration

The `short_url` method uses the `HOST_DOMAIN` environment variable to build the full shortened URL, with a fallback to `localhost:3000`.

## Planned Improvements

1. **URL validation**: Add URL format validation
2. **Caching improvements**: Consider more efficient caching for large databases
3. **Safety breaks**: Add timeout or max attempts to prevent infinite loops
4. **Additional scheme support**: Add support for additional URL schemes beyond HTTP/HTTPS

## Notes

The implementation includes detailed comments explaining the logic and purpose of each component, which should facilitate future maintenance and enhancements.