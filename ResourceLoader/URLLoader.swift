//
//  URLLoader.swift
//  ResourceLoader
//
//  Created by bp on 2018-09-28.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//

import Foundation

/// The type of the identifier for the specific request to load.
public struct ResourceQuery {
    public let url: URL
    fileprivate let id: UInt

    /// Creates a resource query identifier.
    /// - Parameters:
    ///     - id: The number that uniquely identifies a resource query
    ///           in the scope of a specific instance of the URLLoader.
    ///     - url: The URL to which the resource query relates
    fileprivate init(id: UInt, url: URL) {
        self.id = id
        self.url = url
    }
}

extension ResourceQuery: Hashable {

    public var hashValue: Int {
        return self.id.hashValue
    }

    public static func == (lhs: ResourceQuery, rhs: ResourceQuery) -> Bool {
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
class URLLoader<ResourceType: CreatableFromData> {

    /// The type of the closure that is called to process the loaded resource.
    /// - Parameters:
    ///     - result: Loaded resource or nil when the error occured.
    ///     - query: The identifier of the canceled request,
    ///                  returned from the corresponding call
    ///                  of the `requestResource` method.
    typealias AcceptorType = (_ result: ResourceType?, _ query: ResourceQuery) -> ()

    /// Type that represents a reference to the received query.
    private typealias QueryType = (id: UInt, acceptor: AcceptorType)

    /// A data structure containing information about the queries being processed.
    private var queryPool = [URL : (task: URLSessionTask, queries: [QueryType])]()

    /// The dispatch queue used to protect the consistency of
    /// internal data structures in a multithread environment.
    private let poolQueue = DispatchQueue(label: "resourceloader.request", qos: .utility)

    /// The dispatch queue on which callback acceptors for loaded resources will be executed.
    private let acceptorQueue = DispatchQueue(label: "resourceloader.acceptor", qos: .utility)

    private var queryCounter = UInt(0)

    /// Initiate an asynchronous loading of a resource.
    /// - Parameters:
    ///     - url: The URL from which resource should be loaded.
    ///     - acceptor: The completion handler block which called
    ///                 when a load finishes successfully or with an error.
    /// - Returns: Returns an object that uniquely identifies created loading query
    ///            in the scope of a current instance of the URLLoader.
    @discardableResult
    func requestResource(from url: URL, for acceptor: @escaping AcceptorType) -> ResourceQuery {
        var queryId = queryCounter
        poolQueue.sync {
            self.queryCounter = self.queryCounter &+ 1
            queryId = queryCounter
            if let (task, queries) = self.queryPool[url] {
                queryPool[url] = (task: task, queries: queries + [(queryId, acceptor)])
            } else {
                let task = URLSession.shared.dataTask(with: url) {
                    data, response, error in
                    let result = data.flatMap {ResourceType.self.init(data: $0)} 
                    self.poolQueue.async {
                        if let (task, queries) = self.queryPool.removeValue(forKey: url) {
                            assert(task.state == .completed)
                            self.acceptorQueue.async {
                                queries.forEach {
                                    $0.acceptor(result, ResourceQuery(id: $0.id, url: url))
                                }
                            }
                        }
                    }
                }
                self.queryPool[url] = (task: task, queries: [(id: queryId, acceptor: acceptor)])
                task.resume()
            }
        }
        return ResourceQuery(id: queryId, url: url)
    }

    /// Cancel the resource loading.
    /// When the specified loading query already complited or canceled,
    /// subsequent calls to cancel it are ignored.
    /// - Parameter query: The identifier of the canceled request,
    ///                    returned from the corresponding call
    ///                    of the `requestResource` method.
    func cancelRequest(_ query: ResourceQuery) {
        poolQueue.sync {
            guard let (task, queries) = self.queryPool.removeValue(forKey: query.url) else {return}
            let updatedQueries = queries.filter {$0.id != query.id}
            if updatedQueries.isEmpty {
                if .canceling != task.state && .completed != task.state {
                    task.cancel()
                }
            } else {
                self.queryPool[query.url] = (task: task, queries: updatedQueries)
            }
        }
    }
}
