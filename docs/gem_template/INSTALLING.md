> **Architecture Documentation**
> *   **Canonical Source:** [bowerbird-app/recording_studio_youtube](https://github.com/bowerbird-app/RecordingStudio_youtube/tree/main/docs/recording_studio_youtube)
> *   **Last Updated:** May 5, 2026
>
> *Maintainers: Please update the date above when modifying this file.*

---

# Installing in a Host Application

This guide explains how to install the RecordingStudio::YouTube engine in your Rails application.

---

## Prerequisites

- Rails 8.1+ application
- PostgreSQL (recommended for UUID compatibility)
- TailwindCSS (optional, for styling engine views)

---

## Installation Steps

### 1. Add the Gem

Add to your `Gemfile`:

```ruby
# From GitHub
gem "recording_studio_youtube", github: "bowerbird-app/recording_studio_youtube"

# Or from a local path (for development)
gem "recording_studio_youtube", path: "../recording_studio_youtube"

# Or from RubyGems (after publishing)
gem "recording_studio_youtube"
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Run the Install Generator

```bash
rails generate recording_studio_youtube:install
```

This will:
1. **Mount the engine** at `/recording_studio_youtube` in your `config/routes.rb`
2. **Create a configuration initializer** at `config/initializers/recording_studio_youtube.rb`
3. **Optionally create `config/recording_studio_youtube.yml`** for environment-specific settings
4. **Configure Tailwind** to include engine and FlatPack sources (if Tailwind is detected)
5. **Display post-installation instructions**

---

## What the Generator Does

### Routes

Adds this line to `config/routes.rb`:

```ruby
mount RecordingStudio::YouTube::Engine, at: "/recording_studio_youtube"
```

### Configuration

Creates `config/initializers/recording_studio_youtube.rb`:

```ruby
RecordingStudio::YouTube.configure do |config|
  # config.api_key = ENV["youtube_api_key"]
  # config.timeout = 5
end
```

See [CONFIGURATION.md](CONFIGURATION.md) for all options.

### Tailwind CSS

If your app uses Tailwind, the generator adds `@source` directives to include engine views and FlatPack components:

```css
@source "../../vendor/bundle/**/recording_studio_youtube/app/views/**/*.erb";
@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";
```

This ensures Tailwind scans the engine's templates for class names during CSS compilation.

---

## Manual Installation

If you prefer not to use the generator:

### Mount the Engine

Add to `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount RecordingStudio::YouTube::Engine, at: "/recording_studio_youtube"
  # ... your other routes
end
```

### Add Configuration (Optional)

Create `config/initializers/recording_studio_youtube.rb`:

```ruby
RecordingStudio::YouTube.configure do |config|
  config.api_key = ENV["youtube_api_key"]
  config.timeout = 10
end
```

### Configure Tailwind (If Using)

Add to your `app/assets/tailwind/application.css`:

```css
@source "../../vendor/bundle/**/recording_studio_youtube/app/views/**/*.erb";
@source "../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}";
```

Then rebuild:

```bash
bin/rails tailwindcss:build
```

---

## Verifying Installation

1. Start your Rails server:
   ```bash
   bin/rails server
   ```

2. Visit the mounted engine root:
   ```
   http://localhost:3000/recording_studio_youtube
   ```

You should reach the mounted engine root route. In this template repository that route renders the engine home page; downstream addons may wire the mount path differently.

3. If the engine ships migrations, install and run them from the host app:
  ```bash
  rails generate recording_studio_youtube:migrations
  bin/rails db:migrate
  ```

---

## Customizing the Mount Path

Change the mount path in `config/routes.rb`:

```ruby
# Mount at root
mount RecordingStudio::YouTube::Engine, at: "/"

# Mount at a custom path
mount RecordingStudio::YouTube::Engine, at: "/my-engine"

# Mount with constraints
mount RecordingStudio::YouTube::Engine, at: "/recording_studio_youtube", constraints: { subdomain: "api" }
```

---

## Accessing Engine Routes

From your host app views:

```erb
<%= link_to "Visit Engine", recording_studio_youtube.root_path %>
```

From controllers:

```ruby
redirect_to recording_studio_youtube.root_path
```

The `recording_studio_youtube` helper provides access to all engine routes.

## RecordingStudio Host-App Check

This template's dummy app uses RecordingStudio `v4.2.0` (`~> 4.2` in the gemspec). Keep
`config.require_recordable_declarations = true`, declare every configured recordable with
`recording_studio_recordable(...)`, and create roots with `RecordingStudio.root_recording_for(recordable)`.
Child recordings must be created with an explicit `parent_recording`.

When Accessible is bundled, pin the dummy or host Gemfile to `v0.9.1`, run
`bin/rails generate recording_studio_accessible:migrations`, migrate, and rebuild Tailwind after
bumping FlatPack (`v0.1.177`).

---

## Demo Surface

The engine does not ship a browser landing page. Use the dummy app home page as the template demo surface when you want a visible example of the addon experience.

If you want a branded landing page in a host app, create one in your application and route to it separately from the mounted engine.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Route not found | Ensure engine is mounted in `config/routes.rb`. |
| Styles missing | Run `bin/rails tailwindcss:build` after adding `@source`. |
| Generator fails | Check that the gem is installed: `bundle show recording_studio_youtube`. |
| Configuration not applied | Ensure initializer runs after engine loads. |

---

## Uninstalling

1. Remove the mount line from `config/routes.rb`
2. Delete `config/initializers/recording_studio_youtube.rb`
3. Remove the gem from `Gemfile`
4. Run `bundle install`
5. Remove the `@source` line from your Tailwind config

---

## Related Documentation

- [Configuration Guide](CONFIGURATION.md) – All configuration options
- [CSS and JS Assets Architecture](CSS_JS_ASSETS_ARCHITECTURE.md) – How Tailwind and asset scanning are wired

---

Happy integrating!
