//
//  MockHTTPClientTests.swift
//  SwiftHTTPClientTests
//
//  Created by Josh Gallant on 14/07/2025.
//

import XCTest
@testable import SwiftHTTPClient

final class MockHTTPClientTests: XCTestCase {

    func test_givenMock_whenInit_thenRecordedCallsIsEmpty() async {
        // Given
        let mock = MockHTTPClient()
        
        // When
        let recordedCalls = await mock.recordedCalls
        
        // Then
        XCTAssertTrue(recordedCalls.isEmpty)
    }
    
    func test_givenStubbedResult_whenGetIsCalled_thenReturnsStub_andRecordsCall() async {
        // Given
        let mock = MockHTTPClient()
        let data = Data([0, 1, 2])
        let response = HTTPURLResponse(url: URL(string: "https://a.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let expected = HTTPSuccess(data: data, response: response)
        await mock.setGetResult(.success(expected))
        
        // When
        let result = await mock.get("/foo", headers: ["h": "v"], queryItems: ["q": "x"], fragment: "frag", cachePolicy: .reloadIgnoringLocalCacheData)
        let calls = await mock.recordedCalls
        
        // Then
        switch result {
        case .success(let success):
            XCTAssertEqual(success.data, data)
            XCTAssertEqual(success.response.statusCode, 200)
        default:
            XCTFail("Expected .success")
        }
        XCTAssertEqual(calls, [.get(path: "/foo", headers: ["h": "v"], queryItems: ["q": "x"], fragment: "frag")])
    }
    
    func test_givenStubbedResult_whenPostDataIsCalled_thenReturnsStub_andRecordsCall() async {
        // Given
        let mock = MockHTTPClient()
        let data = Data("body".utf8)
        await mock.setPostResult(.failure(.invalidResponse))
        
        // When
        let result = await mock.post("/bar", headers: nil, queryItems: nil, data: data, fragment: nil, cachePolicy: nil)
        let calls = await mock.recordedCalls
        
        // Then
        switch result {
        case .failure(let failure):
            switch failure {
            case .invalidResponse:
                break // Success
            default:
                XCTFail("Expected .invalidResponse")
            }
        default:
            XCTFail("Expected .failure")
        }
        XCTAssertEqual(calls, [.post(path: "/bar", headers: nil, queryItems: nil, data: data, fragment: nil)])
    }
    
    func test_givenStubbedResult_whenPostEncodableIsCalled_thenReturnsStub_andRecordsCall() async {
        // Given
        let mock = MockHTTPClient()
        struct Foo: Encodable {}
        let response = HTTPURLResponse(url: URL(string: "https://mock.com")!, statusCode: 201, httpVersion: nil, headerFields: nil)!
        await mock.setPostResult(.success(HTTPSuccess(data: Data([3,2,1]), response: response)))
        
        // When
        let result = await mock.post("/baz", headers: nil, queryItems: nil, body: Foo(), fragment: "zzz", cachePolicy: .returnCacheDataElseLoad, encoder: JSONEncoder())
        let calls = await mock.recordedCalls
        
        // Then
        switch result {
        case .success(let success):
            XCTAssertEqual(success.response.statusCode, 201)
            XCTAssertEqual(success.data, Data([3,2,1]))
        default:
            XCTFail("Expected .success")
        }
        XCTAssertEqual(calls, [.postEncodable(path: "/baz", headers: nil, queryItems: nil, fragment: "zzz")])
    }
    
    func test_givenStubbedResult_whenPutIsCalled_thenReturnsStub_andRecordsCall() async {
        // Given
        let mock = MockHTTPClient()
        let serverData = Data([9,8])
        await mock.setPutResult(.failure(.server(statusCode: 404, data: serverData)))
        
        // When
        let result = await mock.put("/p", headers: ["A": "B"], queryItems: ["x": "y"], body: serverData, fragment: "abc", cachePolicy: nil)
        let calls = await mock.recordedCalls
        
        // Then
        switch result {
        case .failure(let failure):
            switch failure {
            case .server(let code, let data):
                XCTAssertEqual(code, 404)
                XCTAssertEqual(data, serverData)
            default:
                XCTFail("Expected .server")
            }
        default:
            XCTFail("Expected .failure")
        }
        XCTAssertEqual(calls, [.put(path: "/p", headers: ["A": "B"], queryItems: ["x": "y"], data: serverData, fragment: "abc")])
    }
    
    func test_givenStubbedResult_whenPatchIsCalled_thenReturnsStub_andRecordsCall() async {
        // Given
        let mock = MockHTTPClient()
        let error = NSError(domain: "E", code: 1)
        await mock.setPatchResult(.failure(.encoding(error)))
        let body = Data("123".utf8)
        
        // When
        let result = await mock.patch("/patch", headers: nil, queryItems: nil, body: body, fragment: nil, cachePolicy: nil)
        let calls = await mock.recordedCalls
        
        // Then
        switch result {
        case .failure(let failure):
            switch failure {
            case .encoding(let e as NSError):
                XCTAssertEqual(e.domain, "E")
                XCTAssertEqual(e.code, 1)
            default:
                XCTFail("Expected .encoding NSError")
            }
        default:
            XCTFail("Expected .failure")
        }
        XCTAssertEqual(calls, [.patch(path: "/patch", headers: nil, queryItems: nil, data: body, fragment: nil)])
    }
    
    func test_givenStubbedResult_whenDeleteIsCalled_thenReturnsStub_andRecordsCall() async {
        // Given
        let mock = MockHTTPClient()
        let urlError = URLError(.timedOut)
        await mock.setDeleteResult(.failure(.transport(urlError)))
        let body = Data("del".utf8)
        
        // When
        let result = await mock.delete("/del", headers: ["del": "hdr"], queryItems: ["q": "1"], body: body, fragment: "end", cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        let calls = await mock.recordedCalls
        
        // Then
        switch result {
        case .failure(let failure):
            switch failure {
            case .transport(let err as URLError):
                XCTAssertEqual(err.code, .timedOut)
            default:
                XCTFail("Expected .transport URLError")
            }
        default:
            XCTFail("Expected .failure")
        }
        XCTAssertEqual(calls, [.delete(path: "/del", headers: ["del": "hdr"], queryItems: ["q": "1"], data: body, fragment: "end")])
    }
    
    func test_givenMultipleCalls_whenAllMethodsCalled_thenAllAreRecordedInOrder() async {
        // Given
        let mock = MockHTTPClient()
        struct Foo: Encodable {}
        _ = await mock.get("/a")
        _ = await mock.post("/b", data: nil)
        _ = await mock.post("/c", body: Foo())
        _ = await mock.put("/d", body: nil)
        _ = await mock.patch("/e", body: nil)
        _ = await mock.delete("/f", body: nil)
        
        // When
        let calls = await mock.recordedCalls
        
        // Then
        XCTAssertEqual(calls, [
            .get(path: "/a", headers: nil, queryItems: nil, fragment: nil),
            .post(path: "/b", headers: nil, queryItems: nil, data: nil, fragment: nil),
            .postEncodable(path: "/c", headers: nil, queryItems: nil, fragment: nil),
            .put(path: "/d", headers: nil, queryItems: nil, data: nil, fragment: nil),
            .patch(path: "/e", headers: nil, queryItems: nil, data: nil, fragment: nil),
            .delete(path: "/f", headers: nil, queryItems: nil, data: nil, fragment: nil)
        ])
    }
    
    func test_givenCallEnum_whenEquatableConformance_thenAllCasesAreEquatable() {
        // Given
        let get1 = MockHTTPClient.Call.get(path: "x", headers: nil, queryItems: nil, fragment: nil)
        let get2 = MockHTTPClient.Call.get(path: "x", headers: nil, queryItems: nil, fragment: nil)
        let get3 = MockHTTPClient.Call.get(path: "y", headers: nil, queryItems: nil, fragment: nil)
        
        // When & Then
        XCTAssertEqual(get1, get2)
        XCTAssertNotEqual(get1, get3)
    }
}

