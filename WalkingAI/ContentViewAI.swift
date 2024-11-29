//
//  ContentViewAI.swift
//  WalkingAI
//
//  Created by Brian Quick on 2024-11-24.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreMotion

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var locations: [CLLocation]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: true)
        
        // Remove existing annotations
                uiView.removeAnnotations(uiView.annotations)

                // Add annotations for each location
                for (index, location) in locations.enumerated() {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = location.coordinate
                    
                    let time = DateFormatter.localizedString(from: location.timestamp, dateStyle: .none, timeStyle: .short)
                    annotation.title = "Time: \(time)"
                    
                    if index > 0 {
                        let distance = locations[index - 1].distance(from: location)
                        annotation.subtitle = "Distance: \(String(format: "%.2f", distance)) m"
                    }
                    
                    uiView.addAnnotation(annotation)
                }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }
        
        // Customize annotation view (optional)
                func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                    let identifier = "LocationPin"
                    var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView

                    if annotationView == nil {
                        annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                        annotationView?.canShowCallout = true
                        annotationView?.pinTintColor = .blue
                    } else {
                        annotationView?.annotation = annotation
                    }

                    return annotationView
                }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var region: MKCoordinateRegion
    @Published var locations = [CLLocation]()
    @Published var metersFromHome: Double = 0
    @Published var totalDistance: Double = 0 // Track total distance traveled
    @Published var stepCount: Int = 0 // Track steps
    @Published var isStationary: Bool = false // New property to indicate stationary state
    var startTime: Date = Date() // Start time
    var stopTime: Date = Date()  // Stop time
    @Published var totalTime: TimeInterval = 0.0 // Total time in seconds
    
    
    private var previousLocation: CLLocation? // Keep track of the previous location
    private var recentLocations: [(location: CLLocation, timestamp: Date)] = [] // Buffer of recent locations
    
    private let locationManager = CLLocationManager()
    private var trackingTimer: Timer?
    private let pedometer = CMPedometer() // Add a pedometer instance
    
    @Published var isTracking = false
    
    override init() {
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.98111634, longitude: -81.05080143), // Default to 185 Byron
            latitudinalMeters: 100.0, // 100 yards radius is ~200 meters
            longitudinalMeters: 100.0
        )
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        region.center = location.coordinate
        
        //        print("New location: \(location)")
        
        // calculations to determine if the device is stationary
        let now = Date()
        
        // Add the new location to the buffer
        recentLocations.append((location: location, timestamp: now))
        print(location)
        // Keep only the last 10 seconds of locations
        recentLocations = recentLocations.filter { now.timeIntervalSince($0.timestamp) <= 10 }
        
        // Calculate total movement within the recent locations
        if recentLocations.count > 1 {
            let distances = zip(recentLocations, recentLocations.dropFirst())
                .map { $0.0.location.distance(from: $0.1.location) }
            let totalRecentDistance = distances.reduce(0, +)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss" // Use "HH:mm:ss" for 24-hour format, "hh:mm:ss a" for 12-hour format
            let timeString = dateFormatter.string(from: location.timestamp)
            print ("Total recent distance: \(String(format: "%.2f", totalRecentDistance)) \(timeString)")
            if totalRecentDistance > 9.9 {
                print("Moved")
            }
            // Check if the user is stationary
            isStationary = totalRecentDistance < 5.0  // 5 meters over 10 seconds
                                                      //                    isStationary = totalRecentDistance < 10.0 // 10 meters over 10 seconds
        }
        
        // Ensure the location is accurate and significant movement has occurred
        if let previousLocation = previousLocation {
            let distance = previousLocation.distance(from: location)
            // Distance between first and the current location
            self.metersFromHome = self.locations[0].distance(from: location)
            // Check if the distance exceeds the threshold and if the accuracy is acceptable
            if !self.isStationary {
                
                if distance > 5.0 && location.horizontalAccuracy < 20.0 {
                    totalDistance += distance
                    print("Moved: \(String(format: "%.2f", distance)) meters, accuracy: \(String(format: "%.2f", location.horizontalAccuracy)) meters,Traveled: \(String(format: "%.2f", totalDistance)) meters")
                    
                    self.previousLocation = location // Update previous location only if moved
                    self.locations.append(location)
                    
                } else {
                    print("Moved: \(String(format: "%.2f", distance)) meters, accuracy: \(String(format: "%.2f", location.horizontalAccuracy)) meters,Traveled: \(String(format: "%.2f", totalDistance)) meters IGNORED")
                }
            }
        } else {
            self.previousLocation = location // Initialize previous location
            self.locations.removeAll()
            self.locations.append(location)
            self.totalDistance = 0
            self.stepCount = 0
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        // Check the error type to decide how to handle it
         if let clError = error as? CLError {
             switch clError.code {
             case .locationUnknown:
                 // Retry after a brief delay when the location is temporarily unavailable
                 DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                     self.locationManager.startUpdatingLocation()
                 }
             case .denied:
                 // Handle permission denial
                 print("Location access denied. Please enable permissions in settings.")
             case .network:
                 // Retry when there's a network issue
                 DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                     self.locationManager.startUpdatingLocation()
                 }
             default:
                 print("Unhandled CLError: \(clError.code.rawValue)")
                     Alert(title: Text("Error"), message: Text("Unhandled CLError: \(clError.code.rawValue)"))
             }
         } else {
             print("Unexpected error: \(error)")
         }
    }
    
    func toggleTracking() {
        isTracking.toggle()
        
        if isTracking {
            startTracking()
        } else {
            stopTracking()
        }
    }
    
    private func startTracking() {
        // setting this will clear things on the 1st trip thru the didUpdateLocations
        self.previousLocation = nil
        startTime = Date() // Record the current time
        totalTime = 0.0 // Reset total time
        
        locationManager.startUpdatingLocation()
        
        // Start pedometer updates
        
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                if let error = error {
                    print("Pedometer error:      \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.stepCount = data?.numberOfSteps.intValue ?? 0
                    //                            print("stepCount: \(String(describing: self?.stepCount))")
                }
            }
        }
        
        // Set up a timer to request location updates every 10 seconds
        //        trackingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        //            self?.locationManager.requestLocation()
        //        }
        
        print("Started tracking")
    }
    
    private func stopTracking() {
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        trackingTimer?.invalidate()
        trackingTimer = nil
        stopTime = Date() // Record the stop time
        totalTime = stopTime.timeIntervalSince(startTime) // Calculate the total time
        
        print("Stopped tracking")
    }
    func formatDateToTime(myDate: Date)-> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        return dateFormatter.string(from: myDate)
    }
    func formatTotalTime() -> String {
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60
        let seconds = Int(totalTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        ZStack {
            MapView(region: $locationManager.region, locations: locationManager.locations)

            VStack {
                Spacer()
                HStack {
                    Text("From: \(locationManager.formatDateToTime(myDate: locationManager.startTime))")
                    Text("To: \(locationManager.formatDateToTime(myDate: locationManager.stopTime))")
                    Text("Total: \(locationManager.formatTotalTime())")
                }
                HStack {
                    Text("FromHome: \(locationManager.metersFromHome, specifier: "%.2f") m ")
                    Text("Steps: \(locationManager.stepCount)")
                    Text("Total Traveled: \(locationManager.totalDistance, specifier: "%.2f") m ")
                        .background(locationManager.isStationary ? Color.red : Color.blue)
                        .foregroundColor(.white)
                }

                HStack {
                    Button(locationManager.isTracking ? "Stop Tracking" : "Track Location") {
                        locationManager.toggleTracking()
                    }
                    .padding()
                    .background(locationManager.isTracking ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                    Button("Journal") {
                        sendtoNotes()
                                        }
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                        .padding()
                }
            }
        }
    }
}
extension ContentView {
    func sendtoNotes() {
        let note = "Walking for \(locationManager.formatTotalTime()), \(String(format: "%.2f", locationManager.totalDistance)) meters, and \(locationManager.stepCount) steps"
        
        let shortcutName = "SwiftLogNote" // Replace with the exact name of your Shortcut
        let formattedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "shortcuts://run-shortcut?name=\(shortcutName)&input=\(formattedNote)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url) { success in
                    if success {
                        print("Shortcut successfully called with note: \(note)")
                    } else {
                        print("Failed to call Shortcut.")
                    }
                }
            } else {
                print("Cannot open URL: shortcuts://run-shortcut")
            }
        }
    }
}

#Preview {
    ContentView()
}

