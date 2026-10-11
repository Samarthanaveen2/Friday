import XCTest
@testable import FridayCore

final class PhraseRulesTests: XCTestCase {
    func testWholeWordsOnly() {
        let rules = PhraseRules([.init("sam", "Sam")])
        XCTAssertEqual(rules.apply("sam is the same as samsung, said sam."), "Sam is the same as samsung, said Sam.")
    }

    func testMultiWordAndCaseInsensitive() {
        let rules = PhraseRules([.init("summer tha", "Samartha")])
        XCTAssertEqual(rules.apply("Summer  Tha said hi"), "Samartha said hi")
    }

    func testLongestFirst() {
        let rules = PhraseRules([.init("my email", "a@b.com"), .init("my email address", "x@y.com")])
        XCTAssertEqual(rules.apply("send my email address now"), "send x@y.com now")
    }

    func testSpecialCharactersAreLiteral() {
        let rules = PhraseRules([.init("c++", "C++"), .init("$5", "five dollars")])
        XCTAssertEqual(rules.apply("I like c++"), "I like C++")
        XCTAssertEqual(PhraseRules([]).apply("unchanged"), "unchanged")
    }
}

final class CleanupTests: XCTestCase {
    private func clean(_ s: String) -> String { Cleanup.run(s) }

    func testFillers() {
        XCTAssertEqual(clean("um so I was uh thinking, umm, we could go"), "So I was thinking, we could go.")
        XCTAssertEqual(clean("the umbrella is here"), "The umbrella is here.")
    }

    func testBacktracks() {
        XCTAssertEqual(clean("meet Tuesday, wait, Wednesday at 5"), "Meet Wednesday at 5.")
        XCTAssertEqual(clean("let's do it at 5, no 6"), "Let's do it at 6.")
        XCTAssertEqual(clean("call him tomorrow sorry today"), "Call him today")
        XCTAssertEqual(clean("see you at 4 I mean 5 ok"), "See you at 5 ok.")
        XCTAssertEqual(clean("My birthday is on Tuesday. No wait, it's actually on Wednesday."), "My birthday is on Wednesday.")
        XCTAssertEqual(clean("call me at 5 no make it 6"), "Call me at 6.")
    }

    func testBacktrackLeavesNormalNoAlone() {
        XCTAssertEqual(clean("no I can't come on Tuesday"), "No I can't come on Tuesday.")
        XCTAssertEqual(clean("meet at 5 no problem"), "Meet at 5 no problem.")
    }

    func testStutters() {
        XCTAssertEqual(clean("I I think the the plan works"), "I think the plan works.")
        XCTAssertEqual(clean("it is very very good"), "It is very very good.")
    }

    func testSpokenPunctuation() {
        XCTAssertEqual(clean("hi comma how are you question mark"), "Hi, how are you?")
        XCTAssertEqual(clean("first thing new line second thing"), "First thing\nSecond thing")
        XCTAssertEqual(clean("done full stop next one"), "Done. Next one")
        XCTAssertEqual(clean("Hello, comma, world"), "Hello, world")
    }

    func testLists() {
        XCTAssertEqual(clean("groceries bullet point milk bullet point eggs"), "Groceries\n- Milk\n- Eggs")
        XCTAssertEqual(clean("plan number one wake up number two gym"), "Plan\n1. Wake up\n2. Gym")
        XCTAssertEqual(clean("this is my number one priority today"), "This is my number one priority today.")
    }

    func testFormats() {
        XCTAssertEqual(clean("it costs 500 rupees"), "It costs ₹500")
        XCTAssertEqual(clean("we got 20 percent off"), "We got 20% off.")
        XCTAssertEqual(clean("mail me at rahul.k at gmail dot com"), "Mail me at rahul.k@gmail.com.")
        XCTAssertEqual(clean("open example dot com"), "Open example.com")
    }

    func testCapitalsAndI() {
        XCTAssertEqual(clean("i think i'm late. see you soon"), "I think I'm late. See you soon.")
    }

    func testQuestionsStayQuestions() {
        XCTAssertEqual(clean("what time is the meeting"), "What time is the meeting?")
        XCTAssertEqual(clean("can you send me the notes"), "Can you send me the notes?")
        XCTAssertEqual(clean("do your homework before dinner"), "Do your homework before dinner.")
    }

    func testShortThingsGetNoFullStop() {
        XCTAssertEqual(clean("ok cool"), "Ok cool")
        XCTAssertEqual(clean(""), "")
    }
}

final class ContinuationTests: XCTestCase {
    func testMidSentence() {
        XCTAssertEqual(Continuation.apply("And then we left.", after: "We had dinner"), " and then we left.")
        XCTAssertEqual(Continuation.apply("Rahul came too.", after: "and then"), " Rahul came too.")
        XCTAssertEqual(Continuation.apply("I left.", after: "so"), " I left.")
    }

    func testSentenceStart() {
        XCTAssertEqual(Continuation.apply("Then we left.", after: "Dinner was good. "), "Then we left.")
        XCTAssertEqual(Continuation.apply("Then we left.", after: ""), "Then we left.")
        XCTAssertEqual(Continuation.apply("Then we left.", after: "Done.\n"), "Then we left.")
    }

    func testNoDoubledWord() {
        XCTAssertEqual(Continuation.apply("To go home.", after: "I want to"), " go home.")
    }

    func testPunctuationNeedsNoSpace() {
        XCTAssertEqual(Continuation.apply(", right?", after: "That's it"), ", right?")
    }

    func testDictionaryKeepsCase() {
        XCTAssertEqual(Continuation.apply("Can we meet?", after: "hey", keepCase: []), " can we meet?")
        XCTAssertEqual(Continuation.apply("Samartha said so.", after: "and", keepCase: ["samartha"]), " Samartha said so.")
    }
}

final class GuardTests: XCTestCase {
    func testAcceptsCleanups() {
        XCTAssertTrue(CleanupGuard.check(output: "I think we should go at 5:30.",
                                         transcript: "um I think we should uh go at five thirty").accepted)
        XCTAssertTrue(CleanupGuard.check(output: "Meet Wednesday.", transcript: "meet Tuesday, wait, Wednesday").accepted)
    }

    func testRejectsAnswers() {
        XCTAssertFalse(CleanupGuard.check(output: "The meeting is at 5 pm in room 4.",
                                          transcript: "what time is the meeting").accepted)
        XCTAssertFalse(CleanupGuard.check(output: "Sure! Here's a formal email to your professor asking for an extension...",
                                          transcript: "email the professor asking for an extension").accepted)
    }

    func testRejectsLongerOutput() {
        XCTAssertFalse(CleanupGuard.check(output: "ok ok ok ok ok ok ok ok ok ok ok ok ok ok", transcript: "ok").accepted)
    }

    func testChooseFallsBack() {
        XCTAssertEqual(CleanupGuard.choose(aiOutput: "<out>The answer is 42.</out>", transcript: "what is the answer", fallback: "What is the answer?"),
                       "What is the answer?")
        XCTAssertEqual(CleanupGuard.choose(aiOutput: "<out>What is the answer?</out>", transcript: "what is the answer", fallback: "x"),
                       "What is the answer?")
        XCTAssertEqual(CleanupGuard.choose(aiOutput: nil, transcript: "a", fallback: "A"), "A")
    }

    func testExtractOut() {
        XCTAssertEqual(extractOut("blah <out> Hi there. </out> blah"), "Hi there.")
        XCTAssertEqual(extractOut("Hi there."), "Hi there.")
        XCTAssertNil(extractOut("<out>unterminated"))
        XCTAssertNil(extractOut("   "))
    }
}

final class PhantomAndChunkTests: XCTestCase {
    func testPhantom() {
        XCTAssertEqual(PhantomFilter.clean("Thank you for watching.", deviceHeardSpeech: true), "")
        XCTAssertEqual(PhantomFilter.clean("See you at 5. Thanks for watching!", deviceHeardSpeech: true), "See you at 5.")
        XCTAssertEqual(PhantomFilter.clean("Thank you.", deviceHeardSpeech: true), "Thank you.")
        XCTAssertEqual(PhantomFilter.clean("anything", deviceHeardSpeech: false), "")
    }

    func testJoinChunks() {
        XCTAssertEqual(joinChunks("I was going to the", "to the market today"), "I was going to the market today")
        XCTAssertEqual(joinChunks("Hello there.", "How are you"), "Hello there. How are you")
        XCTAssertEqual(joinChunks("", "Hi"), "Hi")
    }
}

final class DictationFlowTests: XCTestCase {
    func testFullPath() {
        let d = Dictation(fixRules: [.init("summer tha", "Samartha")],
                          snippets: [.init("my email", "sam@example.com")],
                          dictionary: ["Samartha"])
        let prepared = d.prepare("um tell summer tha to mail my email")
        XCTAssertEqual(prepared, "um tell Samartha to mail sam@example.com")
        // AI answers instead of cleaning → rule-based text is used.
        XCTAssertEqual(d.finish(prepared: prepared, aiOutput: "<out>Sure, I've emailed Samartha!</out>", context: "so"),
                       " tell Samartha to mail sam@example.com.")
        // Good AI output is used, then continued from the context.
        XCTAssertEqual(d.finish(prepared: prepared, aiOutput: "<out>Tell Samartha to mail sam@example.com.</out>", context: ""),
                       "Tell Samartha to mail sam@example.com.")
    }

    func testAIMessage() {
        let d = Dictation(dictionary: ["Samartha", "Kharagpur"])
        let m = d.aiMessage(prepared: "hi", context: String(repeating: "x", count: 400), tone: .casual)
        XCTAssertTrue(m.hasPrefix("<context>" + String(repeating: "x", count: 300) + "</context>"))
        XCTAssertTrue(m.contains("<dictionary>Samartha, Kharagpur</dictionary>"))
        XCTAssertTrue(m.contains("<tone>casual</tone>"))
        XCTAssertTrue(m.hasSuffix("<dictation>hi</dictation>"))
        XCTAssertEqual(Tone.formal.next, .asSaid)
    }
}
