//
//  ViewController.swift
//  LocationTracking
//
//  Created by enjay on 24/10/24.
//

import UIKit
import CoreLocation
import MapKit
import GoogleMaps
import Network

class ViewController: UIViewController, CLLocationManagerDelegate  {
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var startButton: UIButton!
    
    
    
    private var lastSentLocation: CLLocationCoordinate2D?
    private var isTracking = false
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocationCoordinate2D?
    private var locations: [CLLocationCoordinate2D] = []
    private var haltTimer: Timer?
    private var haltStartTime: Date?
    private var internetMonitor: NWPathMonitor?
    var timer: Timer?
    private var isInternetConnected: Bool? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        design()
        setupLocationManager()
        setupInternetMonitoring()
       
    }
    func design() {
        containerView.layer.cornerRadius = 10
        containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.4
        containerView.layer.shadowRadius = 10
        mapView.layer.cornerRadius = 10
        startButton.backgroundColor = .systemBlue
        startButton.tintColor = .white
        startButton.layer.cornerRadius = 10
        startButton.setTitle("Start", for: .normal)
    }
    
    func setupLocationManager() {
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(handleLocationUpdate), name: Notification.Name("locationUpdate"), object: nil)
        
        if CLLocationManager.locationServicesEnabled() {
            let locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.requestAlwaysAuthorization()
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    func setupInternetMonitoring() {
        internetMonitor = NWPathMonitor()
            internetMonitor?.pathUpdateHandler = { [weak self] path in
                DispatchQueue.main.async {
                    let isConnected = path.status == .satisfied
                    if self?.isInternetConnected != isConnected {
                        self?.handleInternetStatusChange(isConnected: isConnected)
                        self?.isInternetConnected = isConnected
                    }
                }
            }
            let queue = DispatchQueue.global(qos: .background)
            internetMonitor?.start(queue: queue)
        }
    
    func handleInternetStatusChange(isConnected: Bool) {
        let message = isConnected ? "Internet connected." : "Internet connection lost."
        print(message)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            handleGPSStatusChange(isAvailable: true)
            if isTracking {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
           
            print("Location access denied. GPS is off or restricted.")
            handleGPSStatusChange(isAvailable: false)
        default:
            break
        }
    }
    
    func locationPermisson(){
        let manager = CLLocationManager().authorizationStatus
        switch manager {
        case .authorizedAlways, .authorizedWhenInUse:
            handleGPSStatusChange(isAvailable: true)
            if isTracking {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            print("Location access denied. GPS is off or restricted.")
            handleGPSStatusChange(isAvailable: false)
        default:
            break
        }
    }
    
    func handleGPSStatusChange(isAvailable: Bool) {
        let message = isAvailable ? "GPS is available." : "GPS is not available."
        print(message)
    }
    
    @IBAction func btnClicked(_ sender: Any) {
        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }
    
    
    @objc func handleLocationUpdate(_ notification: Notification) {
            if let locationData = notification.object as? [String: Any],
               let latitude = locationData["latitude"] as? Double,
               let longitude = locationData["longitude"] as? Double {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                
                self.locations.append(coordinate)
                self.drawPolyline()
            }
        }
    private func startTracking() {
        isTracking = true
        startButton.setTitle("Stop", for: .normal)
        startButton.backgroundColor = .systemRed
        locationManager.startUpdatingLocation()
        WebSocketManager.shared.connect()
    }
    
    private func stopTracking() {
        isTracking = false
        startButton.setTitle("Start", for: .normal)
        startButton.backgroundColor = .systemBlue
        locationManager.stopUpdatingLocation()
        WebSocketManager.shared.disconnect()
        haltTimer?.invalidate()
        
        if let lastLocation = locations.last {
            let camera = GMSCameraPosition.camera(withLatitude: lastLocation.latitude, longitude: lastLocation.longitude, zoom: 10)
            mapView.animate(to: camera)
        }
    }
    
    func drawPolyline() {
        let path = GMSMutablePath()
        for location in locations {
            path.add(location)
        }
        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = .systemBlue
        polyline.strokeWidth = 2.0
        polyline.map = mapView
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        
        guard let location = locations.last else { return }
        let coordinate = location.coordinate
        let cameraUpdate = GMSCameraPosition(target: coordinate, zoom: 15)
        mapView.animate(to: cameraUpdate)
        
//        resetHaltTimer()
//        locationPermisson()
        if let lastSentLocation = lastSentLocation {
            let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let previousLocation = CLLocation(latitude: lastSentLocation.latitude, longitude: lastSentLocation.longitude)
            let distance = currentLocation.distance(from: previousLocation)
            
            if distance >= 1 {
                let locationData: [String: Any] = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
                WebSocketManager.shared.sendLocation(data: locationData)
                self.lastSentLocation = coordinate
            }
        } else {
            self.lastSentLocation = coordinate
            let locationData: [String: Any] = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
            WebSocketManager.shared.sendLocation(data: locationData)
        }
        
        
        
        
        self.setupInternetMonitoring()
        self.locations.append(coordinate)
        self.drawPolyline()
    }
    
    
    private func resetHaltTimer() {
        haltTimer?.invalidate()
        haltStartTime = Date()
        
        haltTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            guard let self = self, let haltStartTime = self.haltStartTime else { return }
            let haltLocation = self.lastSentLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
            let haltDuration = Date().timeIntervalSince(haltStartTime)
            
            self.showHaltEvent(at: haltLocation, duration: haltDuration)
        }
    }
    
    private func showHaltEvent(at location: CLLocationCoordinate2D, duration: TimeInterval) {
        let minutes = Int(duration / 60)
        let seconds = Int(duration) % 60
        print("User halted at location (\(location.latitude), \(location.longitude)) for \(minutes) minutes and \(seconds) seconds.")
        
        let marker = GMSMarker(position: location)
        marker.title = "Halted for \(minutes) min \(seconds) sec"
        marker.map = mapView
    }
    
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
    }
    
    func startPermissionCheck() {
        // Running the timer on a background queue
        DispatchQueue.global(qos: .background).async {
            
            DispatchQueue.main.async {
                self.timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                    let status = CLLocationManager.authorizationStatus()
                    switch status {
                    case .authorizedAlways, .authorizedWhenInUse:
                        print("Location access granted.")
                    case .denied, .restricted:
                        print("Location access denied.")
                    default:
                        break
                    }
                }
            }
        }
    }

    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        print("Timer stopped")
    }
}
