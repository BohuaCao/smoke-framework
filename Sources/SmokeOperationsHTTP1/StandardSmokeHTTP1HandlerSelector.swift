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
//  StandardSmokeHTTP1HandlerSelector.swift
//  SmokeOperationsHTTP1
//

import Foundation
import SmokeOperations
import NIOHTTP1
import LoggerAPI
import SmokeHTTP1
import HTTPPathCoding
import ShapeCoding

/**
 Implementation of the SmokeHTTP1HandlerSelector protocol that selects a handler
 based on the case-insensitive uri and HTTP method of the incoming request.
 */
public struct StandardSmokeHTTP1HandlerSelector<ContextType, DefaultOperationDelegateType: HTTP1OperationDelegate>: SmokeHTTP1HandlerSelector {
    public let defaultOperationDelegate: DefaultOperationDelegateType
    
    public typealias SelectorOperationHandlerType = OperationHandler<ContextType,
            DefaultOperationDelegateType.RequestType,
            DefaultOperationDelegateType.ResponseHandlerType>
    
    private struct TokenizedHandler {
        let template: String
        let templateSegments: [HTTPPathSegment]
        let httpMethod: HTTPMethod
        let operationHandler: SelectorOperationHandlerType
    }
    
    let segmentsSeparator: Character = "/"
    
    private var handlerMapping: [String: [HTTPMethod: SelectorOperationHandlerType]] = [:]
    private var tokenizedHandlerMapping: [TokenizedHandler] = []
    
    public init(defaultOperationDelegate: DefaultOperationDelegateType) {
        self.defaultOperationDelegate = defaultOperationDelegate
    }
    
    /**
     Gets the handler to use for an operation with the provided http request
     head.
 
     - Parameters
        - requestHead: the request head of an incoming operation.
     */
    public func getHandlerForOperation(_ uri: String, httpMethod: HTTPMethod) throws -> (SelectorOperationHandlerType, Shape) {
        let lowerCasedUri = uri.lowercased()
        
        guard let handler = handlerMapping[lowerCasedUri]?[httpMethod] else {
            guard let tokenizedHandler = getTokenizedHandler(uri: uri,
                                                             httpMethod: httpMethod) else {
                throw SmokeOperationsError.invalidOperation(reason:
                    "Invalid operation with uri '\(lowerCasedUri)', method '\(httpMethod)'")
                }
            
                return tokenizedHandler
        }
        
        Log.info("Operation handler selected with uri '\(lowerCasedUri)', method '\(httpMethod)'")
            
        return (handler, .null)
    }
    
    private func getTokenizedHandler(uri: String,
                                     httpMethod: HTTPMethod) -> (SelectorOperationHandlerType, Shape)? {
        let pathSegments = Array(uri.split(separator: segmentsSeparator)
            .map(String.init).reversed())
        
        // iterate through each tokenized handler
        for handler in tokenizedHandlerMapping {
            // ignore if not the correct method
            guard handler.httpMethod == httpMethod else {
                continue
            }
            
            guard let shape = getShapeForTemplate(pathSegments: pathSegments,
                                                  tokenizedHandler: handler) else {
                                                    continue
            }
            
            return (handler.operationHandler, shape)
        }
        
        return nil
    }
    
    private func getShapeForTemplate(pathSegments: [String],
                                     tokenizedHandler: TokenizedHandler) -> Shape? {
        var remainingPathSegments = pathSegments
        var remainingTemplateSegments = tokenizedHandler.templateSegments
        var variables: [(String, String?)] = []
        
        // iterate through the path elements
        while let templateSegment = remainingTemplateSegments.popLast() {
            guard let pathSegment = remainingPathSegments.popLast() else {
                return nil
            }
            
            do {
                try templateSegment.parse(value: pathSegment,
                                          variables: &variables,
                                          remainingSegmentValues: remainingPathSegments,
                                          isLastSegment: remainingTemplateSegments.isEmpty)
            } catch {
                return nil
            }
        }

        do {
            let decoderOptions = StandardDecodingOptions(
                shapeKeyDecodingStrategy: .useAsShapeSeparator("."),
                shapeMapDecodingStrategy: .singleShapeEntry)
            let stackValue = try StandardShapeParser.parse(with: variables,
                                                           decoderOptions: decoderOptions)
            
            return stackValue
        } catch {
            return nil
        }
    }
    
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - httpMethod: the http method to add the handler for.
        - handler: the handler to add.
     */
    public mutating func addHandlerForUri(_ uri: String,
                                          httpMethod: HTTPMethod,
                                          handler: SelectorOperationHandlerType) {
        let lowerCasedUri = uri.lowercased()
        
        if addTokenizedUri(uri, httpMethod: httpMethod, handler: handler) {
            return
        }
        
        if var methodMapping = handlerMapping[lowerCasedUri] {
            methodMapping[httpMethod] = handler
            handlerMapping[lowerCasedUri] = methodMapping
        } else {
            handlerMapping[lowerCasedUri] = [httpMethod: handler]
        }
    }
    
    private mutating func addTokenizedUri(_ uri: String,
                                          httpMethod: HTTPMethod,
                                          handler: SelectorOperationHandlerType) -> Bool {
        let tokenizedPath: [HTTPPathSegment]
        do {
            tokenizedPath = try HTTPPathSegment.tokenize(template: uri)
        } catch {
            return false
        }
        
        // if this uri doesn't have any tokens (is a single string token
        if tokenizedPath.count == 1 && tokenizedPath[0].tokens.count == 1,
            case .string = tokenizedPath[0].tokens[0] {
                return false
        }
        
        let templateSegments = Array(tokenizedPath.reversed())
        
        let tokenizedHandler = TokenizedHandler(
            template: uri,
            templateSegments: templateSegments,
            httpMethod: httpMethod, operationHandler: handler)
        
        tokenizedHandlerMapping.append(tokenizedHandler)
        
        return true
    }
}

extension HTTPMethod {
    /// Returns the value of this HTTP method
    var rawValue: String {
        switch self {
        case .GET:
            return "GET"
        case .PUT:
            return "PUT"
        case .ACL:
            return "ACL"
        case .HEAD:
            return "HEAD"
        case .POST:
            return "POST"
        case .COPY:
            return "COPY"
        case .LOCK:
            return "LOCK"
        case .MOVE:
            return "MOVE"
        case .BIND:
            return "BIND"
        case .LINK:
            return "LINK"
        case .PATCH:
            return "PATCH"
        case .TRACE:
            return "TRACE"
        case .MKCOL:
            return "MKCOL"
        case .MERGE:
            return "MERGE"
        case .PURGE:
            return "PURGE"
        case .NOTIFY:
            return "NOTIFY"
        case .SEARCH:
            return "SEARCH"
        case .UNLOCK:
            return "UNLOCK"
        case .REBIND:
            return "REBIND"
        case .UNBIND:
            return "UNBIND"
        case .REPORT:
            return "REPORT"
        case .DELETE:
            return "DELETE"
        case .UNLINK:
            return "UNLINK"
        case .CONNECT:
            return "CONNECT"
        case .MSEARCH:
            return "MSEARCH"
        case .OPTIONS:
            return "OPTIONS"
        case .PROPFIND:
            return "PROPFIND"
        case .CHECKOUT:
            return "CHECKOUT"
        case .PROPPATCH:
            return "PROPPATCH"
        case .SUBSCRIBE:
            return "SUBSCRIBE"
        case .MKCALENDAR:
            return "MKCALENDAR"
        case .MKACTIVITY:
            return "MKACTIVITY"
        case .UNSUBSCRIBE:
            return "UNSUBSCRIBE"
        case .RAW(let value):
            return value
        }
    }
}

extension HTTPMethod: Hashable {
    public var hashValue: Int {
        return rawValue.hashValue
    }
}
