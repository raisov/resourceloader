//
//  NetworkSession.swift
//  ResourceLoader
//
//  Created by bp on 2018-10-03.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//

import Foundation

protocol NetworkSessionDelegate: class {
    func completionHandler(request: Int, didReceive data: Data, with error: Error?)
}

/// This class actually performs the entire load,
/// but delegates loaded data processing.
class NetworkSession: NSObject {

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration,
                          delegate: self, delegateQueue: nil)
    }()

    /// Dispatch queue used to protect consistency of
    /// internal data structures in multithreaded environment.
    private let poolQueue = DispatchQueue(label: "network_session.data", qos: .utility)

    /// URLSessionTask related data.
    private struct TaskData {
        typealias Element = (identifier: Int, request: URLRequest)

        /// Buffer used to collect received data.
        var data = Data()

        /// All requests for the same URL, processed simultaneously.
        private var requests: [Element]

        var attachedRequests: [Int] {return requests.map{$0.identifier}}

        /// May be true when all relevant requests canceled.
        var isEmpty: Bool {return attachedRequests.isEmpty}

        init(_ request: URLRequest, identifier: Int) {
            requests = [(identifier, request)]
        }

        init(_ requests:  ArraySlice<Element>) {
            self.requests = Array(requests)
        }

        mutating func add(_ request: URLRequest, identifier: Int) {
            requests.append((identifier, request))
        }

        mutating func add(contentsOf tail: ArraySlice<Element>) {
            requests.append(contentsOf: tail)
        }

        mutating func removeRequest(with identifier: Int) -> URLRequest? {
            return requests.firstIndex {
                $0.identifier == identifier}.map{self.requests.remove(at: $0)
            }?.request
        }

        /// Remove and return all but first requests.
        mutating func removeTail() -> ArraySlice<Element> {
            guard !requests.isEmpty else {return []}
            let tail = requests.suffix(requests.count - 1)
            requests = [requests[0]]
            return tail
        }
    }

    /// Tasks being processed.
    private var taskPool = [URLSessionTask : TaskData]()

    /// Variable used to generate request identifier.
    static var requestNumber = Int(0)

    unowned var delegate: NetworkSessionDelegate

    /// This class is useless without delegate,
    /// so it is assumed that the creating object set self as a delegate.
    init(delegate: NetworkSessionDelegate) {
        self.delegate = delegate
    }

    /// Create request to load from URL. If this URL currently processed,
    /// request attached to existing task, else new task created.
    /// - Parameter url: loaded resource URL.
    /// - Returns: unique request identifier.
    func makeRequest(url: URL) -> Int {
        let request = URLRequest(url: url)
        var requestId = 0
        poolQueue.sync {
            NetworkSession.requestNumber = NetworkSession.requestNumber &+ 1
            requestId = NetworkSession.requestNumber
            let tasks = self.taskPool.keys
            if let task = (tasks.first{$0.currentRequest?.url == url}) {
                // currently loaded.
                var taskData = self.taskPool[task]!
                taskData.add(request, identifier: requestId)
                self.taskPool[task] = taskData
            } else {
                // new load is initiated.
                let task = self.session.dataTask(with: request)
                self.taskPool[task] = TaskData(request, identifier: requestId)
                task.resume()
            }
        }
        return requestId
    }

    func cancelRequest(_ identifier: Int) {
        poolQueue.sync {
            for (task, taskData) in taskPool {
                var newData = taskData
                if newData.removeRequest(with: identifier) != nil {
                    if newData.isEmpty {
                        task.cancel()
                    } else {
                        taskPool[task] = newData
                    }
                    break
                }
            }
        }
    }
}

extension NetworkSession:
URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate  {

    // MARK: - URLSessionDataDelegate method.

    /// Part of data received.
    func urlSession(_ session: URLSession,
                    dataTask task: URLSessionDataTask,
                    didReceive data: Data) {
            poolQueue.async {
                var taskData = self.taskPool[task]
                taskData?.data.append(data)
                self.taskPool[task] = taskData
            }
    }

    // MARK: - URLSessionTaskDelegate methods.

    /// Response headers received.
    func urlSession(_ session: URLSession,
                    dataTask task: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let response = response as? HTTPURLResponse,
            (400...599).contains(response.statusCode) {
            // HTTP error codes
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    /// Load completed.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        poolQueue.async {
            guard let taskData = self.taskPool.removeValue(forKey: task) else {
                return
            }
            let data = taskData.data
            taskData.attachedRequests.forEach {
                self.delegate.completionHandler(request: $0, didReceive: data, with: error)
            }
        }
    }

    /// URL Redirection.
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        assert((300...399).contains(response.statusCode))
        poolQueue.async {
            if var taskData = self.taskPool.removeValue(forKey: task) {
                // Remove all additional requests for original URL
                let tail = taskData.removeTail()
                self.taskPool[task] = taskData
                if tail.count != 0 {
                    // and start new task for them.
                    let newTask = self.session.dataTask(with: task.originalRequest!)
                    self.taskPool[newTask] = TaskData(tail)
                    newTask.resume()
                }
            }
        }
        completionHandler(request)
    }
}


