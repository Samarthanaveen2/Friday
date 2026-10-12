import XCTest
@testable import FridayCore

final class MoneyTests: XCTestCase {
    private func f(_ s: String) -> String { Money.format(s) }

    func testRupeeCues() {
        XCTAssertEqual(f("It costs 48500 rupees."), "It costs ₹48,500.")
        XCTAssertEqual(f("rupees 48500"), "₹48,500")
        XCTAssertEqual(f("Rs 48500"), "₹48,500")
        XCTAssertEqual(f("Pay Rs. 48,500 today"), "Pay ₹48,500 today")
        XCTAssertEqual(f("Rs.48500"), "₹48,500")
        XCTAssertEqual(f("INR 48500"), "₹48,500")
        XCTAssertEqual(f("₹48500"), "₹48,500")
        XCTAssertEqual(f("₹ 500"), "₹500")
        XCTAssertEqual(f("just 1 rupee"), "just ₹1")
        XCTAssertEqual(f("₹500 rupees"), "₹500")
        XCTAssertEqual(f("2000 Rs."), "₹2,000.")
    }

    func testIndianGrouping() {
        XCTAssertEqual(f("₹150000"), "₹1,50,000")
        XCTAssertEqual(f("₹1,500,000"), "₹15,00,000")
        XCTAssertEqual(f("₹1,50,000"), "₹1,50,000")
        XCTAssertEqual(f("12500000 rupees"), "₹1,25,00,000")
        XCTAssertEqual(f("₹99999"), "₹99,999")
        XCTAssertEqual(f("₹999"), "₹999")
        XCTAssertEqual(Money.indianGrouping("100000"), "1,00,000")
    }

    func testDecimals() {
        XCTAssertEqual(f("₹99.50"), "₹99.50")
        XCTAssertEqual(f("Rs. 1250.75 only"), "₹1,250.75 only")
        XCTAssertEqual(f("It was ₹500."), "It was ₹500.")
    }

    func testLakhCrore() {
        XCTAssertEqual(f("5 lakh rupees"), "₹5 lakh")
        XCTAssertEqual(f("Rs 2 crore"), "₹2 crore")
        XCTAssertEqual(f("2 crore rupees and 1.5 lakhs rupees"), "₹2 crore and ₹1.5 lakhs")
        XCTAssertEqual(f("about 5 lakh people"), "about 5 lakh people")
    }

    func testLeavesOtherNumbersAlone() {
        for s in ["In 2026 we moved.", "Meet at 5:30 or 6:30am.", "Call 9876543210.", "PIN 721302",
                  "Up 20% this year", "It costs $48500", "I have 48500 points", "rupees are weak",
                  "a few hundred rupees", "Takes 3 hrs 20 min"] {
            XCTAssertEqual(f(s), s)
        }
    }
}

final class DictionaryFixTests: XCTestCase {
    private let fix = DictionaryFix(["Priya", "Samarth", "Kharagpur", "Amit", "New Delhi"])

    func testNearMisses() {
        XCTAssertEqual(fix.apply("Tell Preya I'm coming."), "Tell Priya I'm coming.")
        XCTAssertEqual(fix.apply("Priyaa said hi"), "Priya said hi")
        XCTAssertEqual(fix.apply("ask Samart, then leave"), "ask Samarth, then leave")
        XCTAssertEqual(fix.apply("I live in Karagpur."), "I live in Kharagpur.")
        XCTAssertEqual(fix.apply("(Preya)"), "(Priya)")
    }

    func testPossessives() {
        XCTAssertEqual(fix.apply("Preya's bag"), "Priya's bag")
        XCTAssertEqual(fix.apply("Samart’s idea"), "Samarth’s idea")
    }

    func testCapitals() {
        XCTAssertEqual(fix.apply("priya and samarth"), "Priya and Samarth")
        XCTAssertEqual(fix.apply("we flew to new delhi"), "we flew to New Delhi")
    }

    func testRealWordsStay() {
        for s in ["I pray for rain", "The price is right", "Easy prey", "I admit it", "She admitted it",
                  "Sam is here", "Same thing", "Pri said", "Karachi trip", "I don't know"] {
            XCTAssertEqual(fix.apply(s), s)
        }
    }

    func testEmailsAndLinksStay() {
        XCTAssertEqual(fix.apply("mail preya@gmail.com or see preya.in"), "mail preya@gmail.com or see preya.in")
    }

    func testTiesAndEmpty() {
        let two = DictionaryFix(["Rohan", "Rohin"])
        XCTAssertEqual(two.apply("Rohen came"), "Rohen came")
        XCTAssertEqual(DictionaryFix([]).apply("Preya paid 500"), "Preya paid 500")
    }

    func testDistance() {
        XCTAssertEqual(DictionaryFix.distance(Array("preya"), Array("priya"), limit: 3), 1)
        XCTAssertEqual(DictionaryFix.distance(Array("pirya"), Array("priya"), limit: 3), 1)
        XCTAssertEqual(DictionaryFix.distance(Array("pray"), Array("priya"), limit: 3), 2)
    }
}

final class FinishPolishTests: XCTestCase {
    func testFinishAppliesBoth() {
        let d = Dictation(dictionary: ["Priya"])
        let prepared = "tell preya the rent is 48500 rupees"
        // Rule-based path.
        XCTAssertEqual(d.finish(prepared: prepared, aiOutput: nil, context: ""),
                       "Tell Priya the rent is ₹48,500.")
        // AI path.
        XCTAssertEqual(d.finish(prepared: prepared, aiOutput: "<out>Tell Preya the rent is Rs. 48500.</out>", context: ""),
                       "Tell Priya the rent is ₹48,500.")
        // Mid-sentence: the name keeps its capital.
        XCTAssertEqual(d.finish(prepared: "preya still owes 150000 rupees", aiOutput: nil, context: "and"),
                       " Priya still owes ₹1,50,000.")
    }
}

final class SpokenTests: XCTestCase {
    func testEmailLinkAndPhone() {
        let raw = "Mail it to samarth underscore n07 at gmail dot com, and the form is at forms dot gle slash friday"
        XCTAssertEqual(Spoken.symbols(raw), "Mail it to samarth_n07@gmail.com, and the form is at forms.gle/friday")
        XCTAssertEqual(Spoken.symbols("the form is at forms.gle slash friday"), "the form is at forms.gle/friday")
        XCTAssertEqual(Spoken.symbols("write to priya at iitkgp dot ac dot in"), "write to priya@iitkgp.ac.in")
        XCTAssertEqual(Spoken.phoneNumbers("my number is 984-50-12346 and"), "my number is 9845012346 and")
        XCTAssertEqual(Spoken.phoneNumbers("call 98450 12346 now"), "call 9845012346 now")
    }

    func testLeavesOrdinaryTextAlone() {
        XCTAssertEqual(Spoken.symbols("meet at the cafe at 5"), "meet at the cafe at 5")
        XCTAssertEqual(Spoken.symbols("connect the dot to the line"), "connect the dot to the line")
        XCTAssertEqual(Spoken.phoneNumbers("on 12-05-2026 at 5:30"), "on 12-05-2026 at 5:30")
        XCTAssertEqual(Spoken.phoneNumbers("pages 10-20 and 7 people"), "pages 10-20 and 7 people")
    }

    func testMoneyWordsWithoutRupees() {
        XCTAssertEqual(Money.format("Remind me to pay the 2500 lab fee by Thursday."), "Remind me to pay the ₹2,500 lab fee by Thursday.")
        XCTAssertEqual(Money.format("Priya owes me 850 and Arjun paid 2000 for the hotel."), "Priya owes me ₹850 and Arjun paid ₹2,000 for the hotel.")
        XCTAssertEqual(Money.format("The report is 38 pages and I paid 3 visits."), "The report is 38 pages and I paid 3 visits.")
        XCTAssertEqual(Money.format("He spent 40 minutes there."), "He spent 40 minutes there.")
    }
}

final class FillerTests: XCTestCase {
    func testDropsFillersTheAILeft() {
        let ai = "Now, the thing is, I think, I'll add the widget. Okay, yeah, you tap on the, uh, you know, tap, what is that? Uh, I don't, I don't really care, right?"
        XCTAssertEqual(Cleanup.dropFillers(ai),
                       "Now, the thing is, I think, I'll add the widget. Okay, yeah, you tap on the, tap, what is that? I don't really care, right?")
    }

    func testFillerAtStartAndEnd() {
        XCTAssertEqual(Cleanup.dropFillers("Um, so can you send it, uh."), "So can you send it.")
        XCTAssertEqual(Cleanup.dropFillers("so, like, you know, we leave at 6"), "So, we leave at 6")
    }

    func testLeavesRealTextAlone() {
        for text in ["I owe Sam ₹1,00,000 and 1,000 more.", "Do you know Rahul?", "It's like a dream.",
                     "Very, very good.", "Humming a song in the summer.", "- [ ] Milk\n- [ ] Eggs", "Visit forms.gle/friday"] {
            XCTAssertEqual(Cleanup.dropFillers(text), text)
        }
    }
}
