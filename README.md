# Simple shorten URL

## Local development

- Install `WSL` v2 - `Ubuntu` 24.04
```pwsh
wsl --install -d Ubuntu
```
- Dependencies
```sh
sudo apt-get update
sudo apt install build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev
```

- Install `mise` - package management
```sh
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate)"' >> ~/.bashrc
source ~/.bashrc
```

- Ruby `3.4.3`
```sh
mise use --global ruby@3
gem update --system
```

- Rails `8.0.2`
```sh
gem install rails -v 8.0.2
```

- Postgres `16.9`
```sh
sudo apt-get install build-essential libssl-dev libreadline-dev zlib1g-dev libcurl4-openssl-dev uuid-dev icu-devtools libicu-dev libicu74 pkgconf
pkg-config --libs --cflags icu-i18n icu-uc
mise use --global postgres@16
pg_ctl start
```

Access `psql` with
```sh
psql -U postgres
```

Create database role for current user
```sh
psql -U postgres -c "create role $USER"
psql -U postgres -c "alter role $USER SUPERUSER"
psql -U postgres -c "alter role $USER with login"
psql -U postgres -c "create database $USER"
psql -U $USER -c "\password"
```

- Set up database
```sh
# Initialize .env follow .env.sanmple
rails db:create
rails db:migrate
```

- Set up environment variables
Ex: Create `.env` file
```env
# Database configuration
DATABASE_USER=
DATABASE_PASSWORD=
DATABASE_HOST=
DATABASE_PORT=
DATABASE_CONNECTION_POOL=

# Rails environment
RAILS_ENV=
RAILS_MAX_THREADS=
HOST_DOMAIN=
```

- Start server
```sh
cd <project_path>
rails s -p 3000 -b 0.0.0.0
```
