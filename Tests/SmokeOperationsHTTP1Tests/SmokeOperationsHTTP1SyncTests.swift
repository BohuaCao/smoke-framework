// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// SmokeOperationsSyncTests.swift
// SmokeOperationsTests
//

import XCTest
@testable import SmokeOperationsHTTP1
import SmokeOperations
import NIOHTTP1
import SmokeHTTP1

func handleExampleOperationVoid(input: ExampleInput, context: ExampleContext) throws {
    // This function intentionally left blank.
}

func handleExampleHTTP1OperationVoid(input: ExampleHTTP1Input, context: ExampleContext) throws {
    // This function intentionally left blank.
}

func handleBadOperationVoid(input: ExampleInput, context: ExampleContext) throws {
    throw MyError.theError(reason: "Is bad!")
}

func handleBadHTTP1OperationVoid(input: ExampleHTTP1Input, context: ExampleContext) throws {
    throw MyError.theError(reason: "Is bad!")
}

func handleExampleOperation(input: ExampleInput, context: ExampleContext) throws -> OutputAttributes {
    return OutputAttributes(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                            isGreat: true)
}

func handleExampleHTTP1Operation(input: ExampleHTTP1Input, context: ExampleContext) throws -> OutputHTTP1Attributes {
    XCTAssertEqual("headerValue", input.theHeader)
    XCTAssertEqual("muchParameter", input.theParameter)
    XCTAssertEqual("suchToken", input.theToken)
    return OutputHTTP1Attributes(bodyColor: input.theID == "123456789012" ? .blue : .yellow,
                                 isGreat: true,
                                 theHeader: input.theHeader)
}

func handleBadOperation(input: ExampleInput, context: ExampleContext) throws -> OutputAttributes {
    throw MyError.theError(reason: "Is bad!")
}

func handleBadHTTP1Operation(input: ExampleHTTP1Input, context: ExampleContext) throws -> OutputHTTP1Attributes {
    throw MyError.theError(reason: "Is bad!")
}

fileprivate let handlerSelector: StandardSmokeHTTP1HandlerSelector<ExampleContext, JSONPayloadHTTP1OperationDelegate> = {
    var newHandlerSelector = StandardSmokeHTTP1HandlerSelector<ExampleContext, JSONPayloadHTTP1OperationDelegate>(
        defaultOperationDelegate: JSONPayloadHTTP1OperationDelegate())
    newHandlerSelector.addHandlerForUri(
        "exampleoperation", httpMethod: .POST,
        operation: handleExampleOperation,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForUri(
        "exampleoperation/{theToken}", httpMethod: .POST,
        operation: handleExampleHTTP1Operation,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForUri(
        "examplegetoperation", httpMethod: .GET,
        operation: handleExampleOperation,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForUri(
        "examplegetoperation/{theToken}", httpMethod: .GET,
        operation: handleExampleHTTP1Operation,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForUri(
        "examplenobodyoperation", httpMethod: .POST,
        operation: handleExampleOperationVoid,
        allowedErrors: allowedErrors,
        inputLocation: .body)
    
    newHandlerSelector.addHandlerForUri(
        "examplenobodyoperation/{theToken}", httpMethod: .POST,
        operation: handleExampleHTTP1OperationVoid,
        allowedErrors: allowedErrors)
    
    newHandlerSelector.addHandlerForUri(
        "badoperation", httpMethod: .POST,
        operation: handleBadOperation,
        allowedErrors: allowedErrors,
        inputLocation: .body,
        outputLocation: .body)
    
    newHandlerSelector.addHandlerForUri(
        "badoperationvoidresponse", httpMethod: .POST,
        operation: handleBadOperationVoid,
        allowedErrors: allowedErrors,
        inputLocation: .body)
    
    return newHandlerSelector
}()

private func verifyPathOutput(uri: String, body: Data,
                              additionalHeaders: [(String, String)] = []) -> OperationResponse {
    let handler = OperationServerHTTP1RequestHandler(handlerSelector: handlerSelector,
                                                     context: ExampleContext())
    
    var httpRequestHead = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1),
                                          method: .POST,
                                          uri: uri)
    additionalHeaders.forEach { header in
        httpRequestHead.headers.add(name: header.0, value: header.1)
    }
    
    let responseHandler = TestHttpResponseHandler()
    
    handler.handle(requestHead: httpRequestHead, body: body,
                   responseHandler: responseHandler)
    
    return responseHandler.response!
}

private func verifyErrorResponse(uri: String) {
    let response = verifyPathOutput(uri: uri,
                                    body: serializedAlternateInput.data(using: .utf8)!)


    XCTAssertEqual(response.status.code, 400)
    let body = response.responseComponents.body!
    let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                          from: body.data)

    XCTAssertEqual("TheError", output.type)
}

class SmokeOperationsHTTP1SyncTests: XCTestCase {
    
    func testExampleHandler() {
        let response = verifyPathOutput(uri: "exampleOperation",
                                        body: serializedInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 200)
        let body = response.responseComponents.body!
        let output = try! JSONDecoder.getFrameworkDecoder().decode(OutputAttributes.self,
                                                              from: body.data)
        let expectedOutput = OutputAttributes(bodyColor: .blue, isGreat: true)
        XCTAssertEqual(expectedOutput, output)
    }
    
    func testExampleHandlerWithTokenAndQuery() {
        let response = verifyPathOutput(uri: "exampleoperation/suchToken?theParameter=muchParameter",
                                        body: serializedInput.data(using: .utf8)!,
                                        additionalHeaders: [("theHeader", "headerValue")])

        
        XCTAssertEqual(response.status.code, 200)
        let body = response.responseComponents.body!
        let output = try! JSONDecoder.getFrameworkDecoder().decode(OutputBodyAttributes.self,
                                                              from: body.data)
        let expectedOutput = OutputBodyAttributes(bodyColor: .blue, isGreat: true)
        XCTAssertEqual(expectedOutput, output)
    }

    func testExampleVoidHandler() {
        let response = verifyPathOutput(uri: "exampleNoBodyOperation",
                                        body: serializedInput.data(using: .utf8)!)

        let body = response.responseComponents.body
        XCTAssertEqual(response.status.code, 200)
        XCTAssertNil(body)
    }
    
    func testExampleVoidHandlerWithTokenAndQuery() {
        let response = verifyPathOutput(uri: "exampleNoBodyOperation/suchToken?theParameter=muchParameter",
                                        body: serializedInput.data(using: .utf8)!,
                                        additionalHeaders: [("theHeader", "headerValue")])

        let body = response.responseComponents.body
        XCTAssertEqual(response.status.code, 200)
        XCTAssertNil(body)
    }
  
    func testInputValidationError() {
        let response = verifyPathOutput(uri: "exampleOperation",
                                        body: serializedInvalidInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("ValidationError", output.type)
    }
   
    func testOutputValidationError() {
        let response = verifyPathOutput(uri: "exampleOperation",
                                        body: serializedAlternateInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 500)
        let body = response.responseComponents.body!
        let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InternalError", output.type)
    }
    
    func testThrownError() {
        verifyErrorResponse(uri: "badOperationVoidResponse")
        verifyErrorResponse(uri: "badOperation")
    }
    
    func testInvalidOperation() {
        let response = verifyPathOutput(uri: "unknownOperation",
                                        body: serializedAlternateInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
    
    func testIncorrectHTTPMethodOperation() {
        let response = verifyPathOutput(uri: "examplegetoperation",
                                        body: serializedAlternateInput.data(using: .utf8)!)

        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }
    
    func testIncorrectHTTPMethodOperationWithTokenAndQuery() {
         let response = verifyPathOutput(uri: "examplegetoperation/suchToken?theParameter=muchParameter",
                                        body: serializedInput.data(using: .utf8)!,
                                        additionalHeaders: [("theHeader", "headerValue")])
        
        XCTAssertEqual(response.status.code, 400)
        let body = response.responseComponents.body!
        let output = try! JSONDecoder.getFrameworkDecoder().decode(ErrorResponse.self,
                                                              from: body.data)
        
        XCTAssertEqual("InvalidOperation", output.type)
    }

    static var allTests = [
        ("testExampleHandler", testExampleHandler),
        ("testExampleHandlerWithTokenAndQuery", testExampleHandlerWithTokenAndQuery),
        ("testExampleVoidHandler", testExampleVoidHandler),
        ("testInputValidationError", testInputValidationError),
        ("testOutputValidationError", testOutputValidationError),
        ("testThrownError", testThrownError),
        ("testInvalidOperation", testInvalidOperation),
        ("testIncorrectHTTPMethodOperation", testIncorrectHTTPMethodOperation),
        ("testIncorrectHTTPMethodOperationWithTokenAndQuery",
         testIncorrectHTTPMethodOperationWithTokenAndQuery)
    ]
}

