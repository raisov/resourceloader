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
        private var requests: [(identifier: Int, request: URLRequest)]
        var data = Data()
        var attachedRequests: [Int] {return requests.map{$0.identifier}}
        var isEmpty: Bool {return attachedRequests.isEmpty}

        init(with request: URLRequest, identifier: Int) {
            requests = [(identifier, request)]
        }

        mutating func add(request: URLRequest, identifier: Int) {
            requests.append((identifier, request))
        }

        mutating func removeRequest(with identifier: Int) {
            requests.firstIndex{$0.identifier == identifier}.map{_ = requests.remove(at: $0)}
        }

        mutating func removeTail() {
            if !requests.isEmpty {requests = [requests[0]]}
        }
    }

    /// Tasks being processed.
    private var taskPool = [URLSessionTask : TaskData]()

    /// Variable used to generate request identifier.
    static var requestNumber = Int(0)

    unowned var delegate: NetworkSessionDelegate

    init(delegate: NetworkSessionDelegate) {
        self.delegate = delegate
    }

    func makeRequest(url: URL) -> Int {
        let request = URLRequest(url: url)
        var requestId = 0
        poolQueue.sync {
            NetworkSession.requestNumber = NetworkSession.requestNumber &+ 1
            requestId = NetworkSession.requestNumber
            let tasks = self.taskPool.keys
            if let task = (tasks.first{$0.currentRequest?.url == url}) {
                var taskData = self.taskPool[task]!
                taskData.add(request: request, identifier: requestId)
                self.taskPool[task] = taskData
            } else {
                let task = self.session.dataTask(with: request)
                self.taskPool[task] = TaskData(with: request, identifier: requestId)
                task.resume()
            }
        }
        return requestId
    }
}

extension NetworkSession:
URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate  {

    // MARK: - URLSessionDataDelegate method.

    func urlSession(_ session: URLSession,
                    dataTask task: URLSessionDataTask,
                    didReceive data: Data) {
            poolQueue.async {
                var taskData = self.taskPool[task]
                assert(taskData != nil)
                taskData?.data.append(data)
                self.taskPool[task] = taskData
            }
    }

    // MARK: - URLSessionTaskDelegate methods.

    func urlSession(_ session: URLSession,
                    dataTask task: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        assert(taskPool[task] != nil)
        if let response = response as? HTTPURLResponse,
            (400...599).contains(response.statusCode) {
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

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
}


