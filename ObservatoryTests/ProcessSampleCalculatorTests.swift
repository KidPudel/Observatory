import Foundation
import Testing
@testable import ObservatoryDomain

struct ProcessSampleCalculatorTests {
    private let identity = ProcessIdentity(
        processIdentifier: 42,
        startTime: Date(timeIntervalSince1970: 100),
        executablePath: "/Applications/Fixture.app/Contents/MacOS/Fixture"
    )

    @Test
    func usesMonotonicDelayedIntervalForRates() {
        var calculator = ProcessSampleCalculator()
        _ = calculator.calculate(from: raw(at: 10_000_000_000, cpu: 1_000_000_000))

        let sample = calculator.calculate(
            from: raw(
                at: 12_500_000_000,
                cpu: 6_000_000_000,
                read: 5_000,
                written: 10_000,
                wakeups: 25
            )
        )

        #expect(sample.intervalSeconds == 2.5)
        #expect(sample.cpuCoreUsage == 2)
        #expect(sample.diskReadBytesPerSecond == 2_000)
        #expect(sample.diskWriteBytesPerSecond == 4_000)
        #expect(sample.wakeupsPerSecond == 10)
    }

    @Test
    func counterResetStartsANewBaseline() {
        var calculator = ProcessSampleCalculator()
        _ = calculator.calculate(from: raw(at: 1_000_000_000, cpu: 10_000, read: 20_000))
        let reset = calculator.calculate(from: raw(at: 2_000_000_000, cpu: 100, read: 200))
        let recovered = calculator.calculate(from: raw(at: 3_000_000_000, cpu: 1_000_000_100, read: 1_200))

        #expect(reset.cpuCoreUsage == nil)
        #expect(reset.diskReadBytesPerSecond == nil)
        #expect(recovered.cpuCoreUsage == 1)
        #expect(recovered.diskReadBytesPerSecond == 1_000)
    }

    @Test
    func exitClearsBaselineAndDropsCurrentValues() {
        var calculator = ProcessSampleCalculator()
        _ = calculator.calculate(from: raw(at: 1_000_000_000, cpu: 1_000))
        let exited = calculator.calculate(
            from: RawProcessSample(
                process: identity,
                capturedAt: Date(),
                monotonicTimeNanoseconds: 2_000_000_000,
                availability: .exited
            )
        )
        let relaunched = calculator.calculate(from: raw(at: 3_000_000_000, cpu: 2_000))

        #expect(exited.availability == .exited)
        #expect(exited.physicalMemoryBytes == nil)
        #expect(relaunched.intervalSeconds == nil)
        #expect(relaunched.cpuCoreUsage == nil)
    }

    @Test
    func restartedIdentityCannotInheritCounters() {
        var calculator = ProcessSampleCalculator()
        _ = calculator.calculate(from: raw(at: 1_000_000_000, cpu: 1_000_000_000))
        let restarted = ProcessIdentity(
            processIdentifier: identity.processIdentifier,
            startTime: identity.startTime.addingTimeInterval(5),
            executablePath: identity.executablePath
        )
        let sample = calculator.calculate(
            from: raw(
                process: restarted,
                at: 2_000_000_000,
                cpu: 2_000_000_000
            )
        )

        #expect(sample.intervalSeconds == nil)
        #expect(sample.cpuCoreUsage == nil)
    }

    @Test(arguments: [SampleAvailability.inaccessible, .reusedIdentifier])
    func partialFailureRemainsExplicit(_ availability: SampleAvailability) {
        var calculator = ProcessSampleCalculator()
        _ = calculator.calculate(from: raw(at: 1_000_000_000, cpu: 1_000))
        let sample = calculator.calculate(
            from: RawProcessSample(
                process: identity,
                capturedAt: Date(),
                monotonicTimeNanoseconds: 2_000_000_000,
                availability: availability
            )
        )

        #expect(sample.availability == availability)
        #expect(sample.cpuCoreUsage == nil)
        #expect(sample.physicalMemoryBytes == nil)
    }

    private func raw(
        process: ProcessIdentity? = nil,
        at monotonicTime: UInt64,
        cpu: UInt64,
        read: UInt64 = 0,
        written: UInt64 = 0,
        wakeups: UInt64 = 0
    ) -> RawProcessSample {
        RawProcessSample(
            process: process ?? identity,
            capturedAt: Date(timeIntervalSince1970: Double(monotonicTime) / 1_000_000_000),
            monotonicTimeNanoseconds: monotonicTime,
            availability: .available,
            counters: ProcessCounters(
                cpuTimeNanoseconds: cpu,
                physicalMemoryBytes: 64 * 1_024 * 1_024,
                disk: DiskCounters(bytesRead: read, bytesWritten: written),
                wakeups: wakeups,
                threadCount: 8
            )
        )
    }
}
