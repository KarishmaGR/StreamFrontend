import Foundation
import SocketIO

class WebSocketManager {
    static let shared = WebSocketManager()
    
    private var manager: SocketManager!
    private var socket: SocketIOClient!
    private var isConnected = false

//    private let url = URL(string: "https://live-location-a16q.onrender.com")!
    private let url = URL(string: "ws://192.168.176.228:8000")!

    private init() {
        manager = SocketManager(socketURL: url, config: [.log(true), .compress, .reconnects(true)])
        socket = manager.defaultSocket
        
        socket.on(clientEvent: .connect) { data, ack in
            self.isConnected = true
            print("Socket connected")
        }
        
      
        socket.on(clientEvent: .disconnect) { data, ack in
            self.isConnected = false
            print("Socket disconnected")
        }
       
        socket.on("locationUpdate") { data, ack in
            if let locationData = data.first as? [String: Any] {
                print("Received location update: \(locationData)")
                NotificationCenter.default.post(name: Notification.Name("locationUpdate"), object: locationData)
            }
        }

        socket.on(clientEvent: .error) { data, ack in
            if let errorMessage = data.first as? String {
                self.handleError(errorMessage: errorMessage)
            }
        }
    }
    
    func connect() {
        if !isConnected {
            socket.connect()
        }
    }
   
    func disconnect() {
        socket.disconnect()
    }
   
    func sendLocation(data: [String: Any]) {
        if socket.status == .connected {
            socket.emit("locationData", data)
            print("Location data sent: \(data)")
        } else {
            handleError(errorMessage: "Socket not connected. Cannot send location data.")
        }
    }
    
    private func handleError(errorMessage: String) {
     
        print("Error: \(errorMessage)")
        NotificationCenter.default.post(name: Notification.Name("WebSocketError"), object: errorMessage)
    }
}
