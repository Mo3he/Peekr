# Peekr

A native iOS app for monitoring your self-hosted services. Built with SwiftUI, no external dependencies.

## Features

- Monitor any HTTP/HTTPS/TCP service with live status and latency
- Rich integrations with 27 service types: Home Assistant, AdGuard, Grafana, Portainer, Jellyfin, Plex, Sonarr, Radarr, Prowlarr, Overseerr, Proxmox, TrueNAS, Traefik, Unifi, Pi-hole, Nextcloud, Vaultwarden, Immich, Paperless-ngx, Frigate, ntfy, and more
- Live metrics fetched from each service's API
- Latency sparkline and check history per service
- Status event log across all services
- Group services into sections
- Network-aware: pauses local services when you're off your home network (probe-based, no special entitlements)
- Home screen widget (small + medium)
- Background refresh with offline notifications
- Export / import services as JSON
- Credentials stored securely in the system Keychain

## Requirements

- iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project

## Getting Started

```bash
# Install XcodeGen if you don't have it
brew install xcodegen

# Clone and generate the project
git clone https://github.com/mblieden/Peekr.git
cd Peekr
xcodegen generate --spec project.yml

# Open in Xcode
open Peekr.xcodeproj
```

Then build and run on a simulator or device.

## Project Structure

```
Peekr/Sources/
  App/          - App entry point, background task registration
  Models/       - Service, ServiceType, ServiceStatus, StatusEvent, StatusHistory
  Views/        - SwiftUI views
  ViewModels/   - HomeViewModel
  Services/     - PingService, ServiceStore, NetworkMonitor, KeychainHelper
    Integrations/ - One file per service type integration
PeekrWidget/    - WidgetKit extension
project.yml     - XcodeGen spec (source of truth for the Xcode project)
```

## Adding a New Service Integration

1. Add a case to `ServiceType.swift` with `displayName`, `icon`, `defaultPort`, `authMode`, etc.
2. Create `YourIntegration.swift` in `Services/Integrations/` conforming to `ServiceIntegration`
3. Register it in `IntegrationProvider.integration(for:)` in `ServiceIntegration.swift`

## License

MIT
