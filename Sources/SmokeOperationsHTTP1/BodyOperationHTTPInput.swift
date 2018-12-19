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
//  BodyOperationHTTPInput.swift
//  SmokeOperationsHTTP1
//

import Foundation

/**
 Implementation of the OperationHTTPInputProtocol that only decodes
 the HTTP body.
 */
struct BodyOperationHTTPInput<BodyType: Decodable>: OperationHTTPInputProtocol {
    // This struct doesn't use these types but we must provide a
    // concrete type to satify the protocol
    typealias QueryType = String
    typealias PathType = String
    typealias HeadersType = String
    
    let body: BodyType
    
    static func compose(queryDecodableProvider: () throws -> String,
                        pathDecodableProvider: () throws -> String,
                        bodyDecodableProvider: () throws -> BodyType,
                        headersDecodableProvider: () throws -> String) throws -> BodyOperationHTTPInput {
        let body = try bodyDecodableProvider()
        
        return .init(body: body)
    }
}
