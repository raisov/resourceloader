//
//  URLLoader.swift
//  ResourceLoader
//
//  Created by bp on 2018-09-28.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//

import Foundation

/// The type of the identifier for the specific request to load.
public struct RequestDescriptor {
    public let url: URL
    fileprivate let id: UInt

    /// Creates a resource query identifier.
    /// - Parameters:
    ///     - id: The number that uniquely identifies a resource query
    ///           in the scope of a specific instance of the URLLoader.
    ///     - url: The URL to which the resource query relates
    init(id: UInt, url: URL) {
        self.id = id
        self.url = url
    }
}

extension RequestDescriptor: Hashable {

    public var hashValue: Int {
        return self.id.hashValue
    }

    public static func == (lhs: RequestDescriptor, rhs: RequestDescriptor) -> Bool {
        return lhs.id == rhs.id
    }
}

/// An `URLLoader` is an object that is able to
/// asynchronously load resources identified by URL.
/// The result of the request is representing by the type
/// conforming to the protocol `CreatableFromData`.
/// To ensure conformancy, a type must have an `init?(data: Data)` constructor.
/// Conformance can easily be provided for types
/// such as UIImage, XMLParser and PDFDocument by extensions like:
/// ```
///    extension UIImage: CreatableFromData {}
/// ```
/// For the representation of JSON resources
/// the types `JSONObject` and `JSONArray` are defined having a `value` properties
/// of type `[String : Any] and [Any], respectively.
public class URLLoader<ResourceType: CreatableFromData> {

    /// The type of the callback closure that is called to process the loaded resource.
    /// - Parameters:
    ///     - result: Loaded resource or nil when the error occured.
    ///     - requestId: The identifier of the completed request.
    ///     - arbltrary user data, provided when the corresponding request was made
    public typealias AcceptorType = (_ result: ResourceType?, _ requestId: RequestDescriptor, _ userData: Any?) -> ()

    /// Type that represents a reference to the received request.
    private typealias RequestPoolElementType = (id: UInt, acceptor: AcceptorType)
    /// A data structure containing information about the requests being processed.
    private var requestPool = [URL : (task: URLSessionTask, queries: [RequestPoolElementType])]()

    /// The dispatch queue used to protect the consistency of
    /// internal data structures in a multithread environment.
    private let poolQueue = DispatchQueue(label: "resourceloader.request", qos: .utility)

    /// Used to generate request id.
    private var requestCounter = UInt(0)

    /// The dispatch queue on which callback acceptors for loaded resources will be executed.
    private let callbackQueue: DispatchQueue

    /// Creates URLLoader object.
    /// - Parameter callbackQueue: The dispatch queue on which callback acceptors
    ///                            for loaded resources will be executed.
    ///                            When omitted, DispatchQueue.main will be used.
    public init (callbackQueue: DispatchQueue = DispatchQueue.main) {
        self.callbackQueue = callbackQueue
    }

    /// Initiate an asynchronous loading of a resource.
    /// - Parameters:
    ///     - url: The URL from which resource should be loaded.
    ///     - userData: Arbitrary user data that will be passed to acceptor callback
    ///                 when request will be completed.
    ///     - acceptor: The completion handler closure which called
    ///                 when a load finishes successfully or with an error.
    /// - Returns: an object that uniquely identifies created request
    ///            in the scope of a current instance of the URLLoader.
    @discardableResult
    public func requestResource(from url: URL, userData: Any? = nil, for acceptor: @escaping AcceptorType) -> RequestDescriptor {
        var queryId = requestCounter
        poolQueue.sync {
            self.requestCounter = self.requestCounter &+ 1
            queryId = requestCounter
            if let (task, queries) = self.requestPool[url] {
                requestPool[url] = (task: task, queries: queries + [(queryId, acceptor)])
            } else {
                let task = URLSession.shared.dataTask(with: url) {
                    data, response, error in
                    let result = data.flatMap {ResourceType.self.init(data: $0)} 
                    self.poolQueue.async {
                        if let (task, queries) = self.requestPool.removeValue(forKey: url) {
                            assert(task.state == .completed)
                            self.callbackQueue.async {
                                queries.forEach {
                                    $0.acceptor(result, RequestDescriptor(id: queryId, url: url), userData)
                                }
                            }
                        }
                    }
                }
                self.requestPool[url] = (task: task, queries: [(id: queryId, acceptor: acceptor)])
                task.resume()
            }
        }
        return RequestDescriptor(id: queryId, url: url)
    }

    /// Cancel the resource loading.
    /// When the specified loading query already complited or canceled,
    /// subsequent calls to cancel it are ignored.
    /// - Parameter request: The identifier of the canceling request,
    ///                    returned from the corresponding call
    ///                    of the `requestResource` method.
    public func cancelRequest(_ request: RequestDescriptor) {
        poolQueue.sync {
            guard let (task, queries) = self.requestPool.removeValue(forKey: request.url) else {return}
            let updatedQueries = queries.filter {$0.id != request.id}
            if updatedQueries.isEmpty {
                if .canceling != task.state && .completed != task.state {
                    task.cancel()
                }
            } else {
                self.requestPool[request.url] = (task: task, queries: updatedQueries)
            }
        }
    }
}
