//
//  URLLoader.swift
//  ResourceLoader
//
//  Created by bp on 2018-09-28.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//

import Foundation

/// Protocol used to hashing resources

protocol DataCache {
    init(capacity: Int)
    subscript(index: Int) -> Data? {get set}
    func cleanUp()
}


/// Descriptor type for the specific request to load.
public struct RequestDescriptor {
    public let url: URL
    fileprivate let id: UInt

    /// Create resource request descriptor.
    /// - Parameters:
    ///     - id: number that uniquely identifying resource request.
    ///           in scope of the URLLoader instance.
    ///     - url: The URL related to the resource request.
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

/// `URLLoader` is an object asynchronously load resources identified by URL.
/// The result of the request is represented by the type
/// conforming to `CreatableFromData` protocol.
/// To ensure conformance the type must have an `init?(data: Data)` constructor.
/// Conformance can easily be provided for types
/// such as UIImage, XMLParser and PDFDocument by extensions as follows:
/// ```
///    extension UIImage: CreatableFromData {}
/// ```
/// To representat JSON resources the types `JSONObject` and `JSONArray`
/// are defined having `value` property of type
/// `[String : Any] and [Any] respectively.
public class URLLoader<ResourceType: CreatableFromData> {
    /// Result or request type
    public  enum Result {
        case success(ResourceType)
        case empty
        case error(Error)

        init(data: Data?, error: Error? = nil) {
            if let error = error {
                self = Result.error(error)
            } else if let resource = (data.flatMap{ResourceType.self.init(data: $0)}) {
                self = Result.success(resource)
            } else {
                self = Result.empty
            }

        }
    }

    /// The type of the closure called to process loaded resources.
    /// - Parameters:
    ///     - result: Loaded resource or `nil` when the error occured.
    ///     - requestId: completed request descriptor.
    ///     - arbitrary user data provided when the corresponding request was made.
    public typealias AcceptorType = (_ result: Result, _ requestId: RequestDescriptor, _ userData: Any?) -> ()

    /// Type representing request reference.
    private typealias RequestPoolElementType = (id: UInt, acceptor: AcceptorType)
    /// Data structure containing information about requests being processed.
    private var requestPool = [URL : (task: URLSessionTask, queries: [RequestPoolElementType])]()

    /// Limit of cache size.
    private var cacheLimit = 2048 * 1024
    /// Resource cache.
    private var cache: DataCache

    /// Dispatch queue used to protect consistency of
    /// internal data structures in multithreaded environment.
    private let poolQueue = DispatchQueue(label: "resourceloader.data", qos: .utility)

    /// Variable used to generate request id.
    private var requestCounter = UInt(0)

    /// Dispatch queue where callback acceptors will be executed.
    private let callbackQueue: DispatchQueue

    /// Creates URLLoader object.
    /// - Parameter callbackQueue: Dispatch queue where callback acceptors
    ///                            for loaded resources will be executed.
    ///                            When omitted DispatchQueue.main will be used.
    public init (callbackQueue: DispatchQueue = DispatchQueue.main) {
        self.callbackQueue = callbackQueue
        cache = SimpleCache(capacity: cacheLimit)
    }

    /// Initiate asynchronous loading of the resource.
    /// - Parameters:
    ///     - url: loaded resource URL.
    ///     - userData: Arbitrary user data passed to acceptor callback
    ///                 when request is completed.
    ///     - acceptor: The completion handler closure called
    ///                 when the load succeeds or fails.
    /// - Returns: descriptor uniquely identifying created request
    ///            in current URLLoader instance scope.
    @discardableResult
    public func requestResource(from url: URL,
                               userData: Any? = nil,
                               for acceptor: @escaping AcceptorType)
        -> RequestDescriptor {
            var requestId = requestCounter
            poolQueue.sync {
                self.requestCounter = self.requestCounter &+ 1
                requestId = requestCounter

                if let data = cache[url.hashValue] {
                    callbackQueue.async {
                        let result = Result(data: data)
                        let descriptor = RequestDescriptor(id: requestId, url: url)
                        acceptor(result, descriptor, userData)
                    }
                } else if let (task, queries) = self.requestPool[url] {
                    requestPool[url] = (task: task, queries: queries + [(requestId, acceptor)])
                } else {
                    let task = URLSession.shared.dataTask(with: url) {
                        data, response, error in
                        if let data = data {
                            self.cache[url.hashValue] = data
                        }
                        let result = Result(data: data, error: error)
                        self.poolQueue.async {
                            if let (task, queries) = self.requestPool.removeValue(forKey: url) {
                                assert(task.state == .completed)
                                self.callbackQueue.async {
                                    queries.forEach {
                                        $0.acceptor(result, RequestDescriptor(id: requestId, url: url), userData)
                                    }
                                }
                            }
                        }
                    }
                    self.requestPool[url] = (task: task, queries: [(id: requestId, acceptor: acceptor)])
                    task.resume()
                }
            }
        return RequestDescriptor(id: requestId, url: url)
    }

    /// Cancel resource loading.
    /// When  specified loading query already completed or canceled,
    /// subsequent calls to cancelRequest are ignored.
    /// - Parameter request: canceling request descriptor
    ///                    returned from the `requestResource` method corresponding call.
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
