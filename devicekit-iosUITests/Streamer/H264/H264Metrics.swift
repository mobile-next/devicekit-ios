import os

final class H264Metrics: @unchecked Sendable {
    private var captureTimes: [UInt64] = []
    private var convertTimes: [UInt64] = []
    private var encodeTimes: [UInt64] = []
    private var frameTimes: [UInt64] = []
    private var frameIntervals: [UInt64] = []

    private(set) var framesCapured: UInt64 = 0
    private(set) var framesEncoded: UInt64 = 0
    private(set) var framesDroppedCapture: UInt64 = 0
    private(set) var framesDroppedConversion: UInt64 = 0
    private(set) var framesDroppedEncoding: UInt64 = 0
    private(set) var framesSkipped: UInt64 = 0

    private(set) var totalBytesOutput: UInt64 = 0
    private(set) var naluCount: UInt64 = 0
    private(set) var idrFrameCount: UInt64 = 0
    private var naluSizes: [Int] = []

    private let sessionStartTime: UInt64
    private var lastFrameTime: UInt64 = 0
    private let targetFPS: Int
    private let targetBitrate: Int

    private let lock = NSLock()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "devicekit-ios",
        category: "H264Metrics"
    )

    init(targetFPS: Int, targetBitrate: Int) {
        self.targetFPS = targetFPS
        self.targetBitrate = targetBitrate
        self.sessionStartTime = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    }

    func recordCapture(durationNs: UInt64, success: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if success {
            captureTimes.append(durationNs)
            framesCapured += 1
        } else {
            framesDroppedCapture += 1
        }
    }

    func recordConversion(durationNs: UInt64, success: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if success {
            convertTimes.append(durationNs)
        } else {
            framesDroppedConversion += 1
        }
    }

    func recordEncode(durationNs: UInt64, success: Bool) {
        lock.lock()
        defer { lock.unlock() }

        if success {
            encodeTimes.append(durationNs)
            framesEncoded += 1
        } else {
            framesDroppedEncoding += 1
        }
    }

    func recordFrameComplete(totalDurationNs: UInt64) {
        lock.lock()
        defer { lock.unlock() }

        frameTimes.append(totalDurationNs)

        let now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        if lastFrameTime > 0 {
            frameIntervals.append(now - lastFrameTime)
        }
        lastFrameTime = now
    }

    func recordNALU(size: Int, isIDR: Bool) {
        lock.lock()
        defer { lock.unlock() }

        totalBytesOutput += UInt64(size)
        naluCount += 1
        naluSizes.append(size)
        if isIDR {
            idrFrameCount += 1
        }
    }

    func recordFrameSkipped() {
        lock.lock()
        defer { lock.unlock() }
        framesSkipped += 1
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

    private func getMemoryFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.phys_footprint) : 0
    }

    private func getCPUUsage() -> Double {
        CPUUsageMonitor().cpuUsage()
    }

    private func buildSections() -> [ReportSection] {
        let now = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
        let sessionDurationSec = Double(now - sessionStartTime) / 1_000_000_000

        let avgCaptureMs = average(captureTimes) / 1_000_000
        let avgConvertMs = average(convertTimes) / 1_000_000
        let avgEncodeMs = average(encodeTimes) / 1_000_000
        let avgFrameMs = average(frameTimes) / 1_000_000

        let p50FrameMs = Double(percentile(frameTimes, 0.50)) / 1_000_000
        let p95FrameMs = Double(percentile(frameTimes, 0.95)) / 1_000_000
        let p99FrameMs = Double(percentile(frameTimes, 0.99)) / 1_000_000

        let avgIntervalNs = average(frameIntervals)
        let actualFPS = avgIntervalNs > 0 ? 1_000_000_000 / avgIntervalNs : 0

        let bandwidthBps = sessionDurationSec > 0 ? Double(totalBytesOutput * 8) / sessionDurationSec : 0
        let bandwidthKbps = bandwidthBps / 1000
        let bandwidthMbps = bandwidthBps / 1_000_000

        let throughput = sessionDurationSec > 0 ? Double(framesEncoded) / sessionDurationSec : 0

        let avgNaluSize = naluSizes.isEmpty ? 0 : naluSizes.reduce(0, +) / naluSizes.count

        let totalDropped = framesDroppedCapture + framesDroppedConversion + framesDroppedEncoding
        let totalAttempted = framesCapured + framesDroppedCapture
        let dropRate = totalAttempted > 0 ? Double(totalDropped) / Double(totalAttempted) * 100 : 0

        let memoryMB = Double(getMemoryFootprint()) / 1_000_000
        let cpuUsage = getCPUUsage()

        let fpsEfficiency = actualFPS / Double(targetFPS) * 100
        let bitrateEfficiency = bandwidthBps > 0 ? bandwidthBps / Double(targetBitrate) * 100 : 0

        let session = ReportSection(
            title: "Session",
            metrics: [
                Metric(name: "Duration", value: .double(sessionDurationSec), unit: "s"),
                Metric(name: "Frames Encoded", value: .uint(framesEncoded), unit: nil),
                Metric(name: "Frames Captured", value: .uint(framesCapured), unit: nil),
                Metric(name: "Frames Skipped", value: .uint(framesSkipped), unit: nil)
            ]
        )

        let timing = ReportSection(
            title: "Timing (ms)",
            metrics: [
                Metric(name: "Capture avg", value: .double(avgCaptureMs), unit: "ms"),
                Metric(name: "Convert avg", value: .double(avgConvertMs), unit: "ms"),
                Metric(name: "Encode avg", value: .double(avgEncodeMs), unit: "ms"),
                Metric(name: "Frame avg", value: .double(avgFrameMs), unit: "ms"),
                Metric(name: "Frame p50", value: .double(p50FrameMs), unit: "ms"),
                Metric(name: "Frame p95", value: .double(p95FrameMs), unit: "ms"),
                Metric(name: "Frame p99", value: .double(p99FrameMs), unit: "ms")
            ]
        )

        let video = ReportSection(
            title: "Video",
            metrics: [
                Metric(name: "Target FPS", value: .int(targetFPS), unit: nil),
                Metric(name: "Actual FPS", value: .double(actualFPS), unit: nil),
                Metric(name: "FPS Efficiency", value: .double(fpsEfficiency), unit: "%"),
                Metric(name: "Throughput", value: .double(throughput), unit: " frames/sec"),
                Metric(name: "Frame Drops", value: .uint(totalDropped), unit: nil),
                Metric(name: "Drop Rate", value: .double(dropRate), unit: "%"),
                Metric(name: "Dropped (capture)", value: .uint(framesDroppedCapture), unit: nil),
                Metric(name: "Dropped (convert)", value: .uint(framesDroppedConversion), unit: nil),
                Metric(name: "Dropped (encode)", value: .uint(framesDroppedEncoding), unit: nil)
            ]
        )

        let bandwidth = ReportSection(
            title: "Bandwidth",
            metrics: [
                Metric(
                    name: "Target Bitrate",
                    value: .double(Double(targetBitrate) / 1_000_000),
                    unit: " Mbps"
                ),
                Metric(
                    name: "Actual Bitrate",
                    value: .double(bandwidthMbps),
                    unit: " Mbps"
                ),
                Metric(
                    name: "Bitrate Efficiency",
                    value: .double(bitrateEfficiency),
                    unit: "%"
                ),
                Metric(
                    name: "Rate (kbps)",
                    value: .double(bandwidthKbps),
                    unit: " kbps"
                ),
                Metric(
                    name: "Total Data",
                    value: .double(Double(totalBytesOutput) / 1_000_000),
                    unit: " MB"
                )
            ]
        )

        let nal = ReportSection(
            title: "NAL Units",
            metrics: [
                Metric(name: "Total NALs", value: .uint(naluCount), unit: nil),
                Metric(name: "IDR Frames", value: .uint(idrFrameCount), unit: nil),
                Metric(name: "Avg NAL Size", value: .int(avgNaluSize), unit: " bytes")
            ]
        )

        let system = ReportSection(
            title: "System",
            metrics: [
                Metric(name: "Memory", value: .double(memoryMB), unit: " MB"),
                Metric(name: "CPU", value: .double(cpuUsage), unit: "%")
            ]
        )

        return [session, timing, video, bandwidth, nal, system]
    }

    func generateReport() -> String {
        let sections = buildSections()

        return AsciiReportRenderer().render(
            sections: sections,
            title: "H264 STREAM METRICS REPORT"
        )
    }

    func logSummary() {
        logger.info("\n\(self.generateReport())")
    }
}
