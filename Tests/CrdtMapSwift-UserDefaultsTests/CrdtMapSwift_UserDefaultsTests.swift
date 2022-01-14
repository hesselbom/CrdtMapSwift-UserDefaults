import XCTest
import CrdtMapSwift
@testable import CrdtMapSwift_UserDefaults

class MockUserDefaults: UserDefaults {
    private var dict: [String: Any?] = [:]
    override func set(_ value: Any?, forKey defaultName: String) {
        dict[defaultName] = value
    }
    override func value(forKey key: String) -> Any? {
        return dict[key] ?? nil
    }
    override func object(forKey defaultName: String) -> Any? {
        return dict[defaultName] ?? nil
    }
}

final class CrdtMapSwift_UserDefaultsTests: XCTestCase {
    func testGetsDataAfterSync() throws {
        let userDefaults = MockUserDefaults()
        
        var doc = CrdtMapSwift()
        var handler = CrdtMapSwift_UserDefaults(key: "DEMO", doc: doc, userDefaults: userDefaults)
        
        // Should contain no keys
        var dict = doc.toDict()
        XCTAssertEqual(dict.count, 0)
        
        let expectation = self.expectation(description: "Loaded")
        handler.whenSynced { expectation.fulfill() }
        waitForExpectations(timeout: 5, handler: nil)
        
        // Should still only contain 0 keys after syncing first time
        dict = doc.toDict()
        XCTAssertEqual(dict.count, 0)
        
        let expectation2 = self.expectation(description: "Saved to UserDefaults")
        handler.onUpdateOrSnapshotTimerCallback = { expectation2.fulfill() }
        
        // Set post sync key
        doc.set("postsync", "postsync")
        
        // Wait for postsync to be stored
        waitForExpectations(timeout: 5, handler: nil)
        
        // Destroy instance and get a new one, which should get all keys
        handler.destroy()
        
        doc = CrdtMapSwift()
        handler = CrdtMapSwift_UserDefaults(key: "DEMO", doc: doc, userDefaults: userDefaults)
        doc.set("presync", "presync")
        
        // Should contain 1 key (presync)
        dict = doc.toDict()
        XCTAssertEqual(dict.count, 1)
        
        let expectation3 = self.expectation(description: "Loaded")
        handler.whenSynced { expectation3.fulfill() }
        waitForExpectations(timeout: 5, handler: nil)
        
        // Should now contain both presync and postsync keys due to UserDefaults being loaded
        dict = doc.toDict()
        XCTAssertEqual(dict.count, 2)
    }
}
