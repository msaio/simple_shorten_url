# Diary
## Day 1: Environment setup
Guide: https://gorails.com/setup/windows/11
- Install WSL 2 : Ubuntu 24.04
- Install mise  : 025.5.3 linux-x64 (2025-05-09)
- Install ruby  : 3.4.3
- Install rails : 8.0.2
- Create a new Rails application: simple_shorten_url
- Public to github

## Day 2: Tasks clarify
### Requirements
- Ruby
- 2 enpoints
  - `/encode` : Encode <Original URL> to <Shortened URL> : response JSON 
  - `/decode` : Decode <Shorted URL> to <Original URL> : response JSON
- Persistence between encoded and decoded message
- Unit test + Integration test
- Document with mark down
  - List down knowing issues and vulnerabilities
  - Give suggestion for enhancement or different approaches

## Day 3: Preparation
- Hosting: Heroku
- Domain: `superlong.site` (Hostinger)
- DNS: Clouflare

## Day 4: Database setup
- Install postgres
- Add environment file
- Update database configuration

## Day 5: Basic function
- `Url` model
- `Url` controller for 2 `/encode` and `/decode` endpoints
- Include test suites

## Day 6: Documentation
- Update README.md
- Add docs/*