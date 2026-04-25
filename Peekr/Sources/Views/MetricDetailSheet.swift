import SwiftUI

struct MetricDetailSheet: View {
    let metric: ServiceMetric
    let serviceName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Current value
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(metric.color.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: metric.icon)
                                .font(.title2)
                                .foregroundStyle(metric.color)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.label)
                                .font(.headline)
                            Text(metric.value)
                                .font(.title2.monospacedDigit().bold())
                                .foregroundStyle(metric.isAlert ? metric.color : .primary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // Description
                if let desc = MetricDescriptions.description(for: metric.label) {
                    Section("About this metric") {
                        Text(desc)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // Thresholds
                if let thresholds = MetricDescriptions.thresholds(for: metric.label) {
                    Section("Thresholds") {
                        ForEach(thresholds, id: \.label) { t in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(t.color)
                                    .frame(width: 10, height: 10)
                                Text(t.label)
                                    .font(.subheadline)
                                Spacer()
                                Text(t.range)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Alert indicator
                if metric.isAlert {
                    Section {
                        Label("This metric is in an alert state and may need attention.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(serviceName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Descriptions

enum MetricDescriptions {
    struct Threshold {
        let label: String
        let range: String
        let color: Color
    }

    static func description(for label: String) -> String? {
        descriptions[label.lowercased()]
    }

    static func thresholds(for label: String) -> [Threshold]? {
        thresholdMap[label.lowercased()]
    }

    private static let descriptions: [String: String] = [
        "cpu": "Current processor utilization across all cores. High sustained CPU usage can cause slowdowns and instability.",
        "ram": "How much physical memory is in use. When RAM fills up, the system may start swapping to disk, significantly slowing performance.",
        "disk": "Storage space used on the primary filesystem. Running out of disk space can cause services to fail.",
        "load": "System load average over the last minute. Represents how many processes are competing for CPU time. On a 4-core system, a load of 4.0 means all cores are busy.",
        "swap": "Virtual memory (disk used as RAM overflow). High swap usage usually means the system is under memory pressure.",
        "network": "Current network throughput on the primary interface. Shows inbound (↓) and outbound (↑) data rates.",
        "uptime": "How long the system has been running without a restart.",
        "memory": "Physical RAM usage. On routers and small devices, this shows available memory for active processes.",
        "wan": "Status of the WAN (internet-facing) network interface.",
        "wan ip": "The public IP address assigned to the WAN interface.",
        "active interfaces": "Number of network interfaces currently up and active on the device.",
        "dhcp clients": "Number of devices currently assigned IP addresses via DHCP.",
        "version": "The software version currently running on this service.",
        "active streams": "Number of media streams currently being played to clients.",
        "transcoding": "Number of streams being re-encoded on-the-fly. Transcoding is CPU-intensive; direct play is preferred.",
        "connected clients": "Number of client applications currently connected to the server.",
        "movies": "Total number of movies in the library.",
        "tv shows": "Total number of TV series in the library.",
        "episodes": "Total number of individual TV episodes across all series.",
        "songs": "Total number of music tracks in the library.",
        "movie libraries": "Number of configured movie library sections.",
        "tv libraries": "Number of configured TV show library sections.",
        "music libraries": "Number of configured music library sections.",
        "environments": "Number of Docker environments (endpoints) managed by Portainer.",
        "running": "Number of Docker containers currently in a running state.",
        "stopped": "Number of Docker containers that exist but are not running. Stopped containers still consume disk space.",
        "images": "Total number of Docker images stored across all environments.",
        "volumes": "Total number of Docker named volumes across all environments.",
        "entities": "Total number of entities registered in Home Assistant. Entities represent devices, sensors, and services.",
        "lights": "Home Assistant light entities - shows how many are currently on vs total.",
        "switches": "Home Assistant switch entities - shows how many are currently on vs total.",
        "binary_sensors": "Home Assistant binary sensors (on/off sensors like door contacts, motion detectors).",
        "unavailable": "Entities in an unavailable state, usually due to a disconnected device or integration error.",
        "updates available": "Home Assistant integrations, add-ons, or core components with available updates.",
        "blocked today": "Number of DNS requests blocked today by Pi-hole. Blocked queries are typically ads and tracking domains.",
        "block rate": "Percentage of DNS queries blocked today. A rate between 10-30% is typical for most networks.",
        "queries today": "Total DNS queries processed today across all clients.",
        "clients": "Number of unique devices that have made DNS queries.",
        "blocklist": "Total number of domains in the active blocklist.",
        "gravity updated": "How long ago the Pi-hole blocklist (gravity) was last updated. Updates are recommended weekly.",
        "status": "Whether the Pi-hole DNS blocking is currently active.",
        "http routers": "Number of HTTP routing rules configured in Traefik.",
        "errored routes": "Traefik routes that are not in an enabled state, often due to misconfiguration or unreachable backends.",
        "services": "Backend services registered in Traefik that traffic can be routed to.",
        "middlewares": "Middleware plugins configured in Traefik for request/response transformation.",
        "pools healthy": "Number of TrueNAS storage pools in a healthy state.",
        "critical alerts": "Active critical-level alerts on the TrueNAS system requiring immediate attention.",
        "update available": "A software update is available for this system.",
        "nodes": "Number of Proxmox hypervisor nodes in the cluster.",
        "vms running": "Number of QEMU virtual machines and LXC containers currently running.",
        "cpu%": "Average CPU utilization across all Proxmox nodes.",
        "ram%": "Average RAM utilization across all Proxmox nodes.",
        "download speed": "Current aggregate download throughput across all active torrents.",
        "upload speed": "Current aggregate upload throughput to peers.",
        "torrents": "Total number of torrents and their download/seeding state breakdown.",
        "free space": "Available disk space in the download directory.",
        "series": "Total number of TV series tracked in Sonarr.",
        "movies": "Total number of movies tracked in Radarr.",
        "monitored": "Series configured to automatically download new episodes.",
        "missing": "Monitored movies that have not yet been downloaded.",
        "queue": "Items currently being downloaded or awaiting import.",
        "free space": "Available disk space on the media storage drive.",
        "photos": "Total number of photos managed by Immich.",
        "videos": "Total number of videos managed by Immich.",
        "storage used": "Total disk space used by the media library.",
        "albums": "Number of albums created in Immich.",
        "cameras": "Number of cameras configured in Frigate and how many are actively detecting motion.",
        "detection fps": "Frames per second being processed by the object detection pipeline.",
        "cpu (detect)": "CPU usage of the Frigate object detection process.",
        "events today": "Number of detection events recorded today.",
        "documents": "Total number of documents stored in Paperless-ngx.",
        "inbox": "Documents in the inbox awaiting tagging and filing.",
        "tags": "Number of tags configured for document organization.",
        "correspondents": "Number of correspondent contacts configured.",
        "doc types": "Number of document type categories configured.",
        "pending tasks": "Background tasks queued for processing (e.g., OCR, thumbnail generation).",
        "version": "The currently running software version.",
        "location": "The Home Assistant instance location name.",
        "pending requests": "Media requests submitted through Overseerr awaiting approval.",
        "total users": "Number of user accounts registered in Overseerr.",
        "database": "Grafana database backend status.",
        "datasources": "Number of data source connections configured in Grafana.",
        "dashboards": "Number of dashboards created in Grafana.",
        "alerts firing": "Number of Grafana alerting rules currently in a firing state.",
        "active now": "Users active in Nextcloud within the last 5 minutes.",
        "free space": "Remaining storage available for Nextcloud data.",
        "users": "Total registered user accounts.",
        "files": "Total number of files stored in Nextcloud.",
        "app updates": "Nextcloud applications with available updates.",
        "wifi clients": "Devices currently connected to a UniFi wireless access point.",
        "lan clients": "Devices currently connected to the UniFi network via wired or wireless.",
        "wan latency": "Round-trip ping time to the internet as measured by the UniFi controller.",
        "users": "Total number of Vaultwarden user accounts.",
        "active now": "Users active in the last 5 minutes.",
    ]

    private static let thresholdMap: [String: [Threshold]] = [
        "cpu": [
            Threshold(label: "Normal",   range: "0 - 70%",  color: .green),
            Threshold(label: "Warning",  range: "70 - 90%", color: .orange),
            Threshold(label: "Critical", range: "> 90%",    color: .red),
        ],
        "ram": [
            Threshold(label: "Normal",   range: "0 - 75%",  color: .green),
            Threshold(label: "Warning",  range: "75 - 90%", color: .orange),
            Threshold(label: "Critical", range: "> 90%",    color: .red),
        ],
        "disk": [
            Threshold(label: "Normal",   range: "0 - 80%",  color: .green),
            Threshold(label: "Warning",  range: "80 - 95%", color: .orange),
            Threshold(label: "Critical", range: "> 95%",    color: .red),
        ],
        "swap": [
            Threshold(label: "Normal",   range: "0 - 50%",  color: .green),
            Threshold(label: "Warning",  range: "50 - 80%", color: .orange),
            Threshold(label: "Critical", range: "> 80%",    color: .red),
        ],
        "load": [
            Threshold(label: "Normal",  range: "0 - 1.0",  color: .green),
            Threshold(label: "Warning", range: "1.0 - 2.0",color: .orange),
            Threshold(label: "High",    range: "> 2.0",    color: .red),
        ],
        "free space": [
            Threshold(label: "Normal",  range: "> 50 GB",    color: .primary),
            Threshold(label: "Warning", range: "10 - 50 GB", color: .orange),
            Threshold(label: "Critical",range: "< 10 GB",    color: .red),
        ],
        "block rate": [
            Threshold(label: "Typical",  range: "10 - 30%", color: .green),
            Threshold(label: "Very high", range: "> 50%",   color: .orange),
        ],
        "wan latency": [
            Threshold(label: "Normal",  range: "< 100 ms",   color: .green),
            Threshold(label: "Warning", range: "> 100 ms",   color: .orange),
        ],
        "cpu (detect)": [
            Threshold(label: "Normal",   range: "0 - 80%",  color: .secondary),
            Threshold(label: "Critical", range: "> 80%",    color: .red),
        ],
    ]
}
