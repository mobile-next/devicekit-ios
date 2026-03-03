import os

final class MJPEGMetrics: @unchecked Sendable {
    private var captureTimes: [UInt64] = []
    private var scaleTimes: [UInt64] = []
    private var frameTimes: [UInt64] = []
    private var frameIntervals: [UInt64] = []

    private(set) var framesCapured: UInt64 = 0
    private(set) var framesDropped: UInt64 = 0
    private(set) var framesScaled: UInt64 = 0

    private(set) var totalBytesOutput: UInt64 = 0
    private var frameSizes: [Int] = []

    private let sessionStartTime: UInt64
    private var lastFrameTime: UInt64 = 0
    private let targetFPS: Int
    private let lock = NSLock()

    private let cpuUsageMonitor = CPUUsageMonitor()
    private let memoryUsageMonitor = MemoryUsageMonitor()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "devicekit-ios",
        category: "MJPEGMetrics"
    )

    init(targetFPS: Int) {
        self.targetFPS = targetFPS
        self.sessionStartTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    }

    func recordCapture(durationNs: UInt64, success: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if success {
            captureTimes.append(durationNs)
            framesCapured += 1
        } else {
            framesDropped += 1
        }
    }

    func recordScale(durationNs: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        scaleTimes.append(durationNs)
        framesScaled += 1
    }

    func recordFrameOutput(size: Int, totalDurationNs: UInt64) {
        lock.lock()
        defer { lock.unlock() }

        totalBytesOutput += UInt64(size)
        frameSizes.append(size)
        frameTimes.append(totalDurationNs)

        let now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        if lastFrameTime > 0 {
            frameIntervals.append(now - lastFrameTime)
        }
        lastFrameTime = now
    }

    private func percentile(_ values: [UInt64], _ p: Double) -> UInt64 {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * p)
        return sorted[index]
    }

    private func average(_ values: [UInt64]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    func logSummary() {
        logger.info("\n\(self.generateReport())")
    }

    private func buildSections() -> [ReportSection] {
        let now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        let sessionDurationSec = Double(now - sessionStartTime) / 1_000_000_000

        let avgCaptureMs = average(captureTimes) / 1_000_000
        let avgScaleMs = average(scaleTimes) / 1_000_000
        let avgFrameMs = average(frameTimes) / 1_000_000

        let p50 = Double(percentile(frameTimes, 0.50)) / 1_000_000
        let p95 = Double(percentile(frameTimes, 0.95)) / 1_000_000
        let p99 = Double(percentile(frameTimes, 0.99)) / 1_000_000

        let avgIntervalNs = average(frameIntervals)
        let actualFPS = avgIntervalNs > 0 ? 1_000_000_000 / avgIntervalNs : 0
        let fpsEfficiency = actualFPS / Double(targetFPS) * 100

        let throughput = sessionDurationSec > 0 ? Double(framesCapured) / sessionDurationSec : 0

        let dropRate = (framesCapured + framesDropped) > 0
            ? Double(framesDropped) / Double(framesCapured + framesDropped) * 100
            : 0

        let bandwidthBps = sessionDurationSec > 0 ? Double(totalBytesOutput * 8) / sessionDurationSec : 0
        let bandwidthKbps = bandwidthBps / 1000
        let bandwidthMbps = bandwidthBps / 1_000_000

        let avgFrameSize = frameSizes.isEmpty ? 0 : frameSizes.reduce(0, +) / frameSizes.count

        let memoryMB = Double(memoryUsageMonitor.getMemoryFootprint()) / 1_000_000
        let cpuUsage = cpuUsageMonitor.cpuUsage()

        let session = ReportSection(
            title: "Session",
            metrics: [
                Metric(name: "Duration", value: .double(sessionDurationSec), unit: "s"),
                Metric(name: "Frames Captured", value: .uint(framesCapured), unit: nil),
                Metric(name: "Frames Scaled", value: .uint(framesScaled), unit: nil),
                Metric(name: "Frames Dropped", value: .uint(framesDropped), unit: nil)
            ]
        )

        let timing = ReportSection(
            title: "Timing (ms)",
            metrics: [
                Metric(name: "Capture avg", value: .double(avgCaptureMs), unit: "ms"),
                Metric(name: "Scale avg", value: .double(avgScaleMs), unit: "ms"),
                Metric(name: "Frame avg", value: .double(avgFrameMs), unit: "ms"),
                Metric(name: "Frame p50", value: .double(p50), unit: "ms"),
                Metric(name: "Frame p95", value: .double(p95), unit: "ms"),
                Metric(name: "Frame p99", value: .double(p99), unit: "ms")
            ]
        )

        let video = ReportSection(
            title: "Video",
            metrics: [
                Metric(name: "Target FPS", value: .int(targetFPS), unit: nil),
                Metric(name: "Actual FPS", value: .double(actualFPS), unit: nil),
                Metric(name: "FPS Efficiency", value: .double(fpsEfficiency), unit: "%"),
                Metric(name: "Throughput", value: .double(throughput), unit: " frames/sec"),
                Metric(name: "Drop Rate", value: .double(dropRate), unit: "%")
            ]
        )

        let bandwidth = ReportSection(
            title: "Bandwidth",
            metrics: [
                Metric(name: "Rate", value: .double(bandwidthMbps), unit: " Mbps"),
                Metric(name: "Rate (kbps)", value: .double(bandwidthKbps), unit: " kbps"),
                Metric(name: "Total Data", value: .double(Double(totalBytesOutput) / 1_000_000), unit: " MB"),
                Metric(name: "Avg Frame Size", value: .int(avgFrameSize), unit: " bytes")
            ]
        )

        let system = ReportSection(
            title: "System",
            metrics: [
                Metric(name: "Memory", value: .double(memoryMB), unit: " MB"),
                Metric(name: "CPU", value: .double(cpuUsage), unit: "%")
            ]
        )

        return [session, timing, video, bandwidth, system]
    }

    func generateReport() -> String {
        let sections = buildSections()

        return AsciiReportRenderer().render(
            sections: sections,
            title: "MJPEG STREAM METRICS REPORT"
        )
    }

}
