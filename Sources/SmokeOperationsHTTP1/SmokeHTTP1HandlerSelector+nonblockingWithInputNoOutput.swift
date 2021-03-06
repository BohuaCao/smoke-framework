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
// SmokeHTTP1HandlerSelector+nonblockingWithInputNoOutput.swift
// SmokeOperationsHTTP1
//

import Foundation
import LoggerAPI
import SmokeOperations
import NIOHTTP1

public extension SmokeHTTP1HandlerSelector {
    /**
     Adds a handler for the specified uri and http method.
 
     - Parameters:
        - uri: The uri to add the handler for.
        - operation: the handler method for the operation.
        - allowedErrors: the errors that can be serialized as responses
          from the operation and their error codes.
        - operationDelegate: optionally an operation-specific delegate to use when
          handling the operation
     */
    public mutating func addHandlerForUri<InputType: ValidatableCodable, ErrorType: ErrorIdentifiableByDescription>(
        _ uri: String,
        httpMethod: HTTPMethod,
        operation: @escaping ((InputType, ContextType, @escaping (Swift.Error?) -> ()) throws -> ()),
        allowedErrors: [(ErrorType, Int)],
        operationDelegate: OperationDelegateType? = nil) {
            let handler = OperationHandler(operation: operation,
                                           allowedErrors: allowedErrors,
                                           operationDelegate: operationDelegate)
        
        addHandlerForUri(uri, httpMethod: httpMethod, handler: handler)
    }
}
