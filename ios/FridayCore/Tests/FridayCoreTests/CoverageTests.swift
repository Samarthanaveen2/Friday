import XCTest
@testable import FridayCore

final class CoverageTests: XCTestCase {
    func testPutsBackASkippedCorrection() {
        // Real dictation: Whisper dropped "cancel beans"; the iPhone heard it but misheard other words.
        let whisper = "Okay, so tomorrow I need to eat clean. I'll probably eat eggs, chicken and beans. Yeah, Channa. And then I think I'll go to gym or... Yeah I will go to gym, yeah sure."
        let device = "Okay so tomorrow I need to eat clean I'll probably eat eggs chicken and beans cancel beans yeah chana and then I think I'll go to Jim or yeah I will go to gym yeah sure"
        let (text, added) = Coverage.fill(primary: whisper, backup: device)
        XCTAssertEqual(added, ["cancel beans"])
        XCTAssertTrue(text.contains("chicken and beans. cancel beans Yeah, Channa."), text)
        // Whisper's own words are kept where the iPhone misheard ("Jim").
        XCTAssertTrue(text.contains("go to gym or..."))
    }

    func testPutsBackASkippedSentenceWithMoney() {
        let whisper = "I want to buy a laptop. The bag is 2,000 rupees."
        let device = "I want to buy a laptop it costs fifty thousand rupees the bag is 2000 rupees"
        let (text, added) = Coverage.fill(primary: whisper, backup: device)
        XCTAssertEqual(added, ["it costs fifty thousand rupees"])
        XCTAssertEqual(text, "I want to buy a laptop. it costs fifty thousand rupees The bag is 2,000 rupees.")
    }

    func testMishearingsAloneChangeNothing() {
        let whisper = "Send the report to Samarth by Friday at 5pm."
        let device = "Send the report to Samarth bye Friday at five p.m."
        XCTAssertEqual(Coverage.fill(primary: whisper, backup: device).added, [])
        let w2 = "I walked 10,000 steps and I'm gonna sleep."
        let d2 = "I walked ten thousand steps and I am going to sleep"
        XCTAssertEqual(Coverage.fill(primary: w2, backup: d2).text, w2)
    }

    func testFillersAndShortRunsAreIgnored() {
        let whisper = "So I think we should go."
        let device = "um so uh I think like we should go"
        XCTAssertEqual(Coverage.fill(primary: whisper, backup: device).text, whisper)
    }

    func testBrokenOrEmptyDeviceTextChangesNothing() {
        let whisper = "Meet me at the station at 9 tomorrow morning, okay?"
        XCTAssertEqual(Coverage.fill(primary: whisper, backup: "").text, whisper)
        XCTAssertEqual(Coverage.fill(primary: whisper, backup: "meet").text, whisper)
        // Device heard something totally different: too much to add, so trust Whisper.
        let other = "meet me the quick brown fox jumps over the lazy dog every single morning in winter"
        XCTAssertEqual(Coverage.fill(primary: whisper, backup: other).text, whisper)
        XCTAssertEqual(Coverage.fill(primary: "", backup: "hello there friend").text, "")
    }

    func testSkippedRunAtTheStartAndEnd() {
        let whisper = "Okay so call mom tonight and buy some milk on the way home."
        let device = "remind me okay so call mom tonight and buy some milk on the way home about dinner"
        let (text, added) = Coverage.fill(primary: whisper, backup: device)
        XCTAssertEqual(added, ["remind me", "about dinner"])
        XCTAssertEqual(text, "remind me Okay so call mom tonight and buy some milk on the way home. about dinner")
        // Far more new words than Whisper had: the device is probably wrong, so nothing changes.
        XCTAssertEqual(Coverage.fill(primary: "call mom tonight.", backup: "remind me to call mom tonight about dinner plans").text,
                       "call mom tonight.")
    }
}
