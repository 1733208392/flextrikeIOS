//
//  flextarget.swift
//  flextarget
//
//  Created by Kai Yang on 2025/11/28.
//

// This file may contain optional test-style code; compile it only when the
// `Testing` module is available to avoid build errors in normal app builds.
#if canImport(Testing)
import Testing

struct flextarget {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}
#else
// Exclude Testing-only code for app builds.
#endif
