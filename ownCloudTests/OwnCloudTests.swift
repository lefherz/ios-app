//
//  ownCloudTests.swift
//  ownCloudTests
//
//  Created by Pablo Carrascal on 07/03/2018.
//  Copyright © 2018 ownCloud. All rights reserved.
//

import XCTest
import EarlGrey

@testable import ownCloud

class OwnCloudTests: XCTestCase {
    
    let demoServer: String = "demo.owncloud.org"

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    /*
     * Passed if: "Add Server" button is enabled
     */
    func testAddServerButtonIsEnabled() {
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("addServer")).assert(with: grey_enabled())
    }

    /*
     * Passed if: Credentials: username, password, server name, and certificate are displayed if connection works to basic auth server
     */
    
    func testCorrectURLShowFields() {
        
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("addServer")).perform(grey_tap())
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("row-url-url")).perform(grey_replaceText(demoServer))
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("row-continue-continue")).perform(grey_tap())
        
        //Asserts
        
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("row-name-name")).assert(grey_sufficientlyVisible())
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("row-credentials-username")).assert(grey_sufficientlyVisible())
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("row-credentials-password")).assert(grey_sufficientlyVisible())
        EarlGrey.select(elementWithMatcher: grey_accessibilityID("row-url-certificate")).assert(grey_sufficientlyVisible())
        
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
