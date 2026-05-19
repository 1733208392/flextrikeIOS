import XCTest
import Foundation

final class FlexTargetTests: XCTestCase {
    func testAutoRefreshAndRetryAfter401() async throws {
        let state = TestState()
        let executor = TestableAuthRequestExecutor()

        let result = try await executor.execute(
            send: {
                await state.incrementRequestCount()
                if await state.isAccessTokenExpired {
                    return .unauthorized
                }
                return .success("ok")
            },
            refresh: {
                await state.incrementRefreshCount()
                await state.setAccessToken("new_token")
            }
        )

        let refreshCount = await state.getRefreshCount()
        let requestCount = await state.getRequestCount()
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(requestCount, 2)
    }

    func testConcurrent401OnlyTriggersOneRefresh() async throws {
        let state = TestState()
        let executor = TestableAuthRequestExecutor()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    _ = try await executor.execute(
                        send: {
                            await state.incrementRequestCount()
                            if await state.isAccessTokenExpired {
                                return .unauthorized
                            }
                            return .success("ok")
                        },
                        refresh: {
                            await state.incrementRefreshCount()
                            try await Task.sleep(nanoseconds: 150_000_000)
                            await state.setAccessToken("new_token")
                        }
                    )
                }
            }
            try await group.waitForAll()
        }

        let refreshCount = await state.getRefreshCount()
        XCTAssertEqual(refreshCount, 1)
    }
}

private actor TestState {
    private var accessToken = "expired"
    private var refreshCount = 0
    private var requestCount = 0

    var isAccessTokenExpired: Bool {
        accessToken == "expired"
    }

    func setAccessToken(_ value: String) {
        accessToken = value
    }

    func incrementRefreshCount() {
        refreshCount += 1
    }

    func incrementRequestCount() {
        requestCount += 1
    }

    func getRefreshCount() -> Int {
        refreshCount
    }

    func getRequestCount() -> Int {
        requestCount
    }
}

private enum MockResponse {
    case success(String)
    case unauthorized
}

private actor RefreshGate {
    private var inFlight: Task<Void, Error>?

    func run(_ block: @escaping () async throws -> Void) async throws {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task {
            try await block()
        }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }
}

private final class TestableAuthRequestExecutor {
    private let gate = RefreshGate()

    func execute(
        send: @escaping () async throws -> MockResponse,
        refresh: @escaping () async throws -> Void
    ) async throws -> String {
        let first = try await send()
        switch first {
        case .success(let value):
            return value
        case .unauthorized:
            try await gate.run(refresh)
            let second = try await send()
            switch second {
            case .success(let value):
                return value
            case .unauthorized:
                throw NSError(domain: "TestableAuthRequestExecutor", code: 401)
            }
        }
    }
}
