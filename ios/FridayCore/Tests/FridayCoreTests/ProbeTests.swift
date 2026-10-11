import Foundation
import XCTest
@testable import FridayCore

final class ProbeTests: XCTestCase {
    func testParsesProfileInsideSignedBlob() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>Name</key><string>SideStore com.samarth.friday</string>
          <key>TeamIdentifier</key><array><string>AB12CD34EF</string></array>
          <key>ExpirationDate</key><date>2026-10-18T10:00:00Z</date>
          <key>Entitlements</key><dict>
            <key>com.apple.security.application-groups</key>
            <array><string>group.com.samarth.friday.AB12CD34EF</string></array>
          </dict>
        </dict></plist>
        """
        var blob = Data([0x30, 0x82, 0x01, 0x00, 0xFF, 0x00])
        blob.append(Data(xml.utf8))
        blob.append(Data([0x00, 0xA0, 0x82]))

        let profile = try XCTUnwrap(ProvisionProfile.parse(blob))
        XCTAssertEqual(profile.teamID, "AB12CD34EF")
        XCTAssertEqual(profile.appGroups, ["group.com.samarth.friday.AB12CD34EF"])
        XCTAssertEqual(profile.name, "SideStore com.samarth.friday")

        let now = ISO8601DateFormatter().date(from: "2026-10-11T09:00:00Z")!
        XCTAssertEqual(profile.daysLeft(now: now), 7)
        XCTAssertEqual(profile.daysLeft(now: now.addingTimeInterval(30 * 86_400)), 0)
    }

    func testGarbageIsNotAProfile() {
        XCTAssertNil(ProvisionProfile.parse(Data("hello".utf8)))
    }

    func testGroupCandidatesOrderAndDedup() {
        let list = AppGroupCandidates.list(
            altAppGroups: ["group.com.samarth.friday.AB12CD34EF"],
            profileGroups: ["group.com.samarth.friday.AB12CD34EF", "*", " "],
            teamID: "AB12CD34EF"
        )
        XCTAssertEqual(list, ["group.com.samarth.friday.AB12CD34EF", "group.com.samarth.friday"])
    }

    func testGroupCandidatesWithNothingKnown() {
        XCTAssertEqual(AppGroupCandidates.list(altAppGroups: [], profileGroups: [], teamID: nil),
                       ["group.com.samarth.friday"])
    }

    func testBeatsRoundTrip() throws {
        let beat = AppBeat(at: Date(timeIntervalSince1970: 1_000), micRunning: true, level: 0.4,
                           inBackground: true, bestBackgroundSeconds: 130, lastPingSeen: 3)
        XCTAssertEqual(ProbeCodec.decode(AppBeat.self, from: try ProbeCodec.encode(beat)), beat)
        let kb = KeyboardBeat(at: Date(timeIntervalSince1970: 2_000), fullAccess: true, ping: 3, roundTrip: true)
        XCTAssertEqual(ProbeCodec.decode(KeyboardBeat.self, from: try ProbeCodec.encode(kb)), kb)
        XCTAssertNil(ProbeCodec.decode(AppBeat.self, from: Data("{}".utf8)))
    }

    func testAgeLabel() {
        XCTAssertEqual(ageLabel(0.5), "now")
        XCTAssertEqual(ageLabel(8), "8s ago")
        XCTAssertEqual(ageLabel(200), "3m ago")
        XCTAssertEqual(ageLabel(7_300), "2h ago")
        XCTAssertEqual(ageLabel(-5), "now")
    }
}
