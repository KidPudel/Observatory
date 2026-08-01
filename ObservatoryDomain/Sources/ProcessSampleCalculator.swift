import Foundation

public struct ProcessSampleCalculator: Sendable {
    private var baselines: [ProcessIdentity: RawProcessSample] = [:]

    public init() {}

    public mutating func resetBaselines(for processes: [ProcessIdentity]) {
        for process in processes {
            baselines.removeValue(forKey: process)
        }
    }

    public mutating func calculate(from rawSample: RawProcessSample) -> ProcessSample {
        defer {
            if rawSample.availability == .available, rawSample.counters != nil {
                baselines[rawSample.process] = rawSample
            } else {
                baselines.removeValue(forKey: rawSample.process)
            }
        }

        guard rawSample.availability == .available, let current = rawSample.counters else {
            return ProcessSample(
                process: rawSample.process,
                capturedAt: rawSample.capturedAt,
                availability: rawSample.availability
            )
        }

        let baseline = baselines[rawSample.process]
        let interval = baseline.flatMap {
            elapsedSeconds(from: $0.monotonicTimeNanoseconds, to: rawSample.monotonicTimeNanoseconds)
        }

        return ProcessSample(
            process: rawSample.process,
            capturedAt: rawSample.capturedAt,
            availability: .available,
            intervalSeconds: interval,
            cpuCoreUsage: rate(
                current: current.cpuTimeNanoseconds,
                previous: baseline?.counters?.cpuTimeNanoseconds,
                interval: interval,
                unitScale: 1_000_000_000
            ),
            physicalMemoryBytes: current.physicalMemoryBytes,
            disk: current.disk,
            diskReadBytesPerSecond: rate(
                current: current.disk.bytesRead,
                previous: baseline?.counters?.disk.bytesRead,
                interval: interval
            ),
            diskWriteBytesPerSecond: rate(
                current: current.disk.bytesWritten,
                previous: baseline?.counters?.disk.bytesWritten,
                interval: interval
            ),
            wakeups: current.wakeups,
            wakeupsPerSecond: rate(
                current: current.wakeups,
                previous: baseline?.counters?.wakeups,
                interval: interval
            ),
            threadCount: current.threadCount
        )
    }

    private func elapsedSeconds(from previous: UInt64, to current: UInt64) -> Double? {
        guard current > previous else { return nil }
        return Double(current - previous) / 1_000_000_000
    }

    private func rate(
        current: UInt64,
        previous: UInt64?,
        interval: Double?,
        unitScale: Double = 1
    ) -> Double? {
        guard
            let previous,
            let interval,
            interval > 0,
            current >= previous
        else {
            return nil
        }

        return Double(current - previous) / unitScale / interval
    }
}
