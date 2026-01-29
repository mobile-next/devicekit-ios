final class CPUUsageMonitor {
    private var lastUserTime: TimeInterval = 0
    private var lastSystemTime: TimeInterval = 0
    private var lastTimestamp: TimeInterval = 0

    func cpuUsage() -> Double {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                          task_flavor_t(TASK_THREAD_TIMES_INFO),
                          $0,
                          &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let user = TimeInterval(info.user_time.seconds) +
                   TimeInterval(info.user_time.microseconds) / 1_000_000

        let system = TimeInterval(info.system_time.seconds) +
                     TimeInterval(info.system_time.microseconds) / 1_000_000

        let now = CFAbsoluteTimeGetCurrent()

        if lastTimestamp == 0 {
            lastTimestamp = now
            lastUserTime = user
            lastSystemTime = system
            return 0
        }

        let deltaTime = now - lastTimestamp
        let deltaCPU = (user - lastUserTime) + (system - lastSystemTime)

        lastTimestamp = now
        lastUserTime = user
        lastSystemTime = system

        return (deltaCPU / deltaTime) * 100
    }
}
