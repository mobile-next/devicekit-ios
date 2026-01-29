enum MetricValue {
    case int(Int)
    case uint(UInt64)
    case double(Double)
    case string(String)
}

struct Metric {
    let name: String
    let value: MetricValue
    let unit: String?
}

struct DistributionMetric {
    let name: String
    let values: [UInt64]  // nanoseconds or bytes or whatever
    let unit: String?
}

protocol MetricComputer {
    func average(_ values: [UInt64]) -> Double
    func percentile(_ values: [UInt64], _ p: Double) -> Double
}

final class DefaultMetricComputer: MetricComputer {
    func average(_ values: [UInt64]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    func percentile(_ values: [UInt64], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let idx = Int(Double(sorted.count - 1) * p)
        return Double(sorted[idx])
    }
}

struct ReportSection {
    let title: String
    let metrics: [Metric]
}

final class AsciiReportRenderer {
    func render(sections: [ReportSection], title: String) -> String {
        var out = ""
        out += "╔" + String(repeating: "═", count: 70) + "╗\n"
        out += "║" + title.centered(width: 70) + "║\n"
        out += "╠" + String(repeating: "═", count: 70) + "╣\n"

        for (i, section) in sections.enumerated() {
            out += "║ \(section.title.uppercased())\n"
            for metric in section.metrics {
                out += "║   \(metric.name): \(format(metric))\n"
            }
            if i < sections.count - 1 {
                out += "╠" + String(repeating: "═", count: 70) + "╣\n"
            }
        }

        out += "╚" + String(repeating: "═", count: 70) + "╝"
        return out
    }

    private func format(_ metric: Metric) -> String {
        switch metric.value {
        case .int(let v): return "\(v)\(metric.unit ?? "")"
        case .uint(let v): return "\(v)\(metric.unit ?? "")"
        case .double(let v): return String(format: "%.2f%@", v, metric.unit ?? "")
        case .string(let s): return s
        }
    }
}

private extension String {
    func centered(width: Int) -> String {
        let padding = max(0, width - count)
        let left = padding / 2
        let right = padding - left
        return String(repeating: " ", count: left) + self + String(repeating: " ", count: right)
    }
}
