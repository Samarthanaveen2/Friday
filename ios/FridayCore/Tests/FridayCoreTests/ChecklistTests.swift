import XCTest
@testable import FridayCore

final class ChecklistTests: XCTestCase {
    func testParseToggleAndBack() {
        var c = Checklist("To buy\n- [ ] Chicken\n- [x] Eggs\n☐ Vegetables")
        XCTAssertTrue(c.hasItems)
        XCTAssertEqual(c.lines[0], .text("To buy"))
        XCTAssertEqual(c.lines[2], .check(done: true, text: "Eggs"))
        XCTAssertEqual(c.lines[3], .check(done: false, text: "Vegetables"))
        c.toggle(at: 1)
        c.setText("Chicken 1 kg", at: 1)
        c.add("Onions")
        c.remove(at: 2)
        XCTAssertEqual(c.text, "To buy\n- [x] Chicken 1 kg\n- [ ] Vegetables\n- [ ] Onions")
        XCTAssertFalse(Checklist("just a note").hasItems)
        XCTAssertEqual(Checklist("").lines, [])
    }

    func testConvertBothWays() {
        XCTAssertEqual(Checklist.makeChecklist("- Chicken\n\n• Eggs\nVegetables"), "- [ ] Chicken\n- [ ] Eggs\n- [ ] Vegetables")
        XCTAssertEqual(Checklist.makePlain("- [ ] Chicken\n- [x] Eggs"), "- Chicken\n- Eggs")
    }

    func testBoxEditOnlyForFridayInstructions() {
        XCTAssertTrue(BoxEdit.isEdit("Friday, make this a checklist."))
        XCTAssertTrue(BoxEdit.isEdit("hey Friday remove the eggs"))
        XCTAssertTrue(BoxEdit.isEdit("Friday, what's left to buy?"))
        XCTAssertFalse(BoxEdit.isEdit("I need to buy chicken, eggs and vegetables. Friday, make that a checklist."))
        XCTAssertFalse(BoxEdit.isEdit("Add milk and bread"))
        XCTAssertFalse(BoxEdit.isEdit("Friday is the deadline for the form"))
    }

    func testBoxEditGuard() {
        let note = "Buy chicken 2 kg, eggs and vegetables"
        XCTAssertTrue(BoxEdit.accept(output: "- [ ] Chicken 2 kg\n- [ ] Eggs\n- [ ] Vegetables", note: note,
                                     instruction: "Friday, make this a checklist"))
        XCTAssertFalse(BoxEdit.accept(output: "- [ ] Chicken 5 kg", note: note, instruction: "Friday, make this a checklist"))
        XCTAssertTrue(BoxEdit.accept(output: note + "\nTotal: 3 items", note: note, instruction: "Friday, how many items?"))
        XCTAssertFalse(BoxEdit.accept(output: "", note: note, instruction: "Friday, delete everything"))
    }
}
