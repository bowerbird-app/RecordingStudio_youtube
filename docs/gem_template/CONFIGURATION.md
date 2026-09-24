> **Architecture Documentation**
> *   **Canonical Source:** [bowerbird-app/recording_studio_youtube](https://github.com/bowerbird-app/RecordingStudio_youtube/tree/main/docs/recording_studio_youtube)
> *   **Last Updated:** May 5, 2026
>
> *Maintainers: Please update the date above when modifying this file.*

---

# RecordingStudio::YouTube Configuration

This document explains how to configure **RecordingStudio::YouTube** in your host Rails application.

---

## Quick Start

After installing the gem, run the install generator:

```bash
rails generate recording_studio_youtube:install
```

This will:

1. Mount the engine in your routes (`/recording_studio_youtube` by default).
2. Create `config/initializers/recording_studio_youtube.rb` with example settings.
3. Optionally create `config/recording_studio_youtube.yml` for environment-specific configuration.

---

## Configuration Options

| Option              | Type    | Default                          | Description                                 |
|---------------------|---------|----------------------------------|---------------------------------------------|
| `api_key`           | String  | `ENV["youtube_api_key"]`    | API key for external service integration.  |
| `timeout`           | Integer | `5`                              | Timeout (seconds) for external calls.      |
| `retries`           | Integer | `1`                              | Extra attempts for HTTP 500 and 503.       |

### RecordingStudio Host-App Declarations

The dummy host app pins RecordingStudio to GitHub tag `v4.2.0` (`~> 4.2` in the gemspec) and keeps strict recordable declarations enabled:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = ["Workspace", "Folder", "Page"]
  config.require_recordable_declarations = true
end

class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
end

class Folder < ApplicationRecord
  recording_studio_recordable label: "Folder", root: false, allowed_parent_types: ["Workspace", "Folder"]
end
```

Use `RecordingStudio.validate_recordable_declarations!`, `RecordingStudio.root_recordable_types`, and
`RecordingStudio.allowed_parent_types_for("Page")` to verify the host app wiring.

---

## Configuration Methods

### 1. Ruby Initializer (Recommended)

Edit `config/initializers/recording_studio_youtube.rb`:

```ruby
RecordingStudio::YouTube.configure do |config|
  config.api_key = ENV["youtube_api_key"]
  config.timeout = 10
end
```

This approach is flexible and allows dynamic values, environment variables, and Rails credentials.

### 2. YAML Configuration

If you prefer environment-specific static settings, create `config/recording_studio_youtube.yml`:

```yaml
development:
  api_key: "dev-key"
  timeout: 5

production:
  api_key: <%= ENV["youtube_api_key"] %>
  timeout: 5
```

The engine loads this file automatically via `Rails.application.config_for(:recording_studio_youtube)`.

### 3. `config.x` Namespace

You can also set values in `config/application.rb` or environment files:

```ruby
# config/environments/production.rb
config.x.recording_studio_youtube.api_key = ENV["youtube_api_key"]
config.x.recording_studio_youtube.timeout = 10
```

---

## Load Order & Precedence

Configuration is merged in the following order (later sources override earlier ones):

1. **Defaults** – defined in `RecordingStudio::YouTube::Configuration#initialize`.
2. **YAML** – `config/recording_studio_youtube.yml` loaded via `config_for`.
3. **`config.x.recording_studio_youtube`** – values set in Rails config files.
4. **Initializer** – `RecordingStudio::YouTube.configure` block in `config/initializers/recording_studio_youtube.rb`.

> **Tip:** For most use cases, stick with the Ruby initializer and use environment variables for secrets.

---

## Accessing Configuration at Runtime

```ruby
RecordingStudio::YouTube.configuration.timeout
# => 5

RecordingStudio::YouTube.configuration.to_h
# => { timeout: 5, retries: 1, api_key_configured: true }
```

You can access these values from anywhere in your application or from within the engine's controllers, models, and jobs.

---

## Secret Management

For sensitive values like `api_key`, we recommend:

- **Environment variables** – `ENV["youtube_api_key"]`
- **Rails credentials** – `Rails.application.credentials.recording_studio_youtube[:api_key]`

Avoid committing secrets to version control. The generator templates use `ENV` by default to encourage this practice.

---

## Extending Configuration

To add new options:

1. Add `attr_accessor` in `lib/recording_studio_youtube/configuration.rb`.
2. Set a sensible default in `#initialize`.
3. Update `#to_h` if you want the option included in hash export.
4. Document the new option in this file and in the initializer template.

---

## Troubleshooting

| Issue                                  | Solution                                                                 |
|----------------------------------------|--------------------------------------------------------------------------|
| YAML not loading                       | Ensure `config/recording_studio_youtube.yml` exists and has valid YAML syntax.       |
| Initializer values not applied         | Make sure the initializer runs after the engine initializer (default).   |
| `config.x` values ignored              | Verify you're setting them in the correct environment file.             |

---

## Files Reference

| File                                                        | Purpose                                      |
|-------------------------------------------------------------|----------------------------------------------|
| `lib/recording_studio_youtube/configuration.rb`                         | Configuration class with defaults.           |
| `lib/recording_studio_youtube/engine.rb`                                | Engine initializer that loads host config.   |
| `lib/generators/recording_studio_youtube/install/install_generator.rb`  | Install generator that creates config files. |
| `lib/generators/recording_studio_youtube/install/templates/`            | Templates for initializer and YAML files.    |

---

Happy configuring!
