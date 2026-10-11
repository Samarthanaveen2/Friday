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

    // The owner's real ramble (eval #64): the junk goes, every finished sentence stays.
    static let ramble = "No, but my question is, look, how does it know about context, though? That's my question. I suppose... Wait... No, it got the time right. That's not a problem. But... Yeah, I understand my question. My question actually is, how can... Wait, I'm forgetting it. Yeah, I got it. Suppose I'm telling something big. Dude, I need to speak it out and then read it again. So I hope there are no mistakes. The act of reading it again is just too much work, man. Is there any way you can... So I just have to trust that it gets the words right, is it?"

    func testDropsThinkingAloudFromARamble() {
        let out = clean(Self.ramble)
        for junk in ["I suppose", "Wait", "But...", "how can", "forgetting", "I got it"] {
            XCTAssertFalse(out.contains(junk), "still has \(junk): \(out)")
        }
        for kept in ["how does it know about context, though?", "That's my question.", "No, it got the time right.",
                     "That's not a problem.", "I understand my question.", "Suppose I'm telling something big.",
                     "Dude, I need to speak it out and then read it again.", "too much work, man.",
                     "Is there any way you can", "trust that it gets the words right, is it?"] {
            XCTAssertTrue(out.contains(kept), "lost \(kept): \(out)")
        }
    }

    func testDropsGivenUpHalfSentence() {
        XCTAssertEqual(clean("so my question is how do we... wait I forgot. yeah I got it. how do we split the bill"),
                       "How do we split the bill?")
        XCTAssertEqual(clean("I was thinking... What was I saying? Let's meet at 5."), "Let's meet at 5.")
        XCTAssertEqual(clean("Call Rahul. But... Tell him I'm late."), "Call Rahul. Tell him I'm late.")
    }

    func testKeepsThingsThatLookLikeSelfTalk() {
        // Said on their own, these are the message.
        XCTAssertEqual(clean("Did you call mom? I forgot."), "Did you call mom? I forgot.")
        XCTAssertEqual(clean("Got it. See you at 5."), "Got it. See you at 5.")
        XCTAssertEqual(clean("Wait, I forgot."), "Wait, I forgot.")
        XCTAssertEqual(clean("I sent the file... Got it?"), "I sent the file... Got it?")
        // A trailing-off thought that carries on is kept.
        XCTAssertEqual(clean("So I was thinking... maybe we go to Goa."), "So I was thinking... maybe we go to Goa.")
        XCTAssertEqual(clean("No... I don't think so."), "No... I don't think so.")
        XCTAssertEqual(clean("It costs 5.30 dollars."), "It costs 5.30 dollars.")
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

    func testAcceptsHeavySelfCorrection() {
        let said = "I know what I need to do this weekend. I need to hang out with my friends. No, no. No wait. I need to study. No, that's not it. What do I need to do? I think I need.. I think.. Yeah, I think I need to go to the swimming pool."
        XCTAssertTrue(CleanupGuard.check(output: "I know what I need to do this weekend. I need to go to the swimming pool.", transcript: said).accepted)
    }

    func testAcceptsLightTouchOnARamble() {
        // Wispr Flow's take on the owner's ramble: fragments and self-talk gone, a few words fixed.
        let wispr = "No but my question is: how does it know about context? That's my question. I suppose it got the time right. That's not the problem. I understand my question. Suppose I'm telling something big: do I need to speak it out and then read it again? I hope there are no mistakes, right? The act of reading it again is just too much work, man. Is there any way you can? I just have to trust that you guess the word, right? Is it?"
        XCTAssertTrue(CleanupGuard.check(output: wispr, transcript: CleanupTests.ramble).accepted)
        XCTAssertTrue(CleanupGuard.check(output: Cleanup.run(CleanupTests.ramble), transcript: CleanupTests.ramble).accepted)
        // Answering the question inside it is still caught.
        let answered = "It uses the text before your cursor and the app you're in to understand context, so you don't need to reread everything you dictate."
        XCTAssertFalse(CleanupGuard.check(output: answered, transcript: CleanupTests.ramble).accepted)
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
        XCTAssertEqual(extractOut("<out>cut off here"), "cut off here")
        XCTAssertEqual(extractOut("No opening tag.</out>"), "No opening tag.")
        XCTAssertEqual(extractOut("<think>\nhmm\n</think>\n<out>Line one\n- Two</out>"), "Line one\n- Two")
        XCTAssertEqual(extractOut("<think></think>\n\nJust text."), "Just text.")
        XCTAssertNil(extractOut("<out>   </out>"))
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

final class PiecePromptTests: XCTestCase {
    func testCarriesTheEndOfThePreviousPiece() {
        let previous = (1...60).map { "w\($0)" }.joined(separator: " ")
        let prompt = Dictation.piecePrompt(base: "Samarth, Groq", previous: previous)
        XCTAssertTrue(prompt.hasPrefix("Samarth, Groq. w21 "))
        XCTAssertTrue(prompt.hasSuffix(" w60"))
        XCTAssertFalse(prompt.contains("w20 "))
    }

    func testFirstPieceAndNoDictionary() {
        XCTAssertEqual(Dictation.piecePrompt(base: "Samarth", previous: nil), "Samarth")
        XCTAssertEqual(Dictation.piecePrompt(base: "Samarth", previous: "  "), "Samarth")
        XCTAssertEqual(Dictation.piecePrompt(base: "", previous: "it costs 50,000 rupees"), "it costs 50,000 rupees")
        XCTAssertEqual(Dictation.piecePrompt(base: "", previous: nil), "")
    }
}

final class VoiceCommandTests: XCTestCase {
    func testFridayCommandIsSpotted() {
        XCTAssertTrue(Dictation.hasCommand("Meet at 5. Friday, change that to 6 PM. And bring notes."))
        XCTAssertTrue(Dictation.hasCommand("friday delete the last line"))
        XCTAssertTrue(Dictation.hasCommand("we need milk and eggs, hey Friday make that a list"))
        XCTAssertTrue(Dictation.hasCommand("The plan is set. Friday, please replace Arjun with Priya."))
    }

    func testFridayTheDayIsJustText() {
        XCTAssertFalse(Dictation.hasCommand("Let's catch up on Friday at the canteen."))
        XCTAssertFalse(Dictation.hasCommand("Friday is the last day to submit the form."))
        XCTAssertFalse(Dictation.hasCommand("See you Friday, make sure you bring the cake."))
        XCTAssertFalse(Dictation.hasCommand("Friday works for me."))
    }
}
