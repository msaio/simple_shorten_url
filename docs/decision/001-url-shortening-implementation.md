# URL Shortening Implementation

## Status

Basic implementation

## Context

Follow what is described as tasks in this [Assignment](https://vn-hiring.iwalabs.info/assignment/6013f139f6f7dea750e9c16c2f5362c4)
We will implement a simple URL shorten service

## In shorts

This implementation will use `Ruby on Rails` as starting point.

Turn `original_url` into `shortened_key` and store them into `postgres` database

## Implementation Details

### URL Model

To generate unique string form `original_url`, we will go through 3 stages:

1. **Stage 1**: Short keys (6 characters)
   - MD5 hash of URL converted to URL-safe Base64
   - Multiple attempts with counter for collision handling

2. **Stage 2**: Long keys (8 characters)
   - Same algorithm with longer output length
   - Used if Stage 1 has collisions

3. **Stage 3**: Random key generation
   - SecureRandom-based keys as final fallback
   - Timestamp-based uniqueness guarantee

Flows to process creating new record:
- `simple_validate_url_format` for basic url validation
- `check_if_url_exists`
- `generate_shortened_key` which has 3 stages mentioned above
- finally let `postgress` validate uniqeness

### URL controllers

Provide 2 endpoints for testing purpose

- POST `/encode` - request body: { url: <original_url>  } - response data: { url: <shortened_url> }
- POST `/decode` - request body: { url: <shortened_url> } - response data: { url: <original_url>  }

### Knowing issues

- Incomplete URL Normalization
- Collision Handling Inefficiency
   - Recursive approach could be broken in high-traffic systems
   - Collision check rely on database query can become performance issue
- Lack of url validation
