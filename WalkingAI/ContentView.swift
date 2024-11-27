////
////  ContentView.swift
////  WalkingAI
////
////  Created by Brian Quick on 2024-11-22.
////
//
//import SwiftUI
//import MapKit
//import CoreLocation
//
//struct MapView: UIViewRepresentable {
//    @Binding var region: MKCoordinateRegion
//    
//    func makeUIView(context: Context) -> MKMapView {
//        let mapView = MKMapView()
//        mapView.showsUserLocation = true
//        mapView.delegate = context.coordinator
//        return mapView
//    }
//    
//    func updateUIView(_ uiView: MKMapView, context: Context) {
//        uiView.setRegion(region, animated: true)
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(self)
//    }
//    
//    class Coordinator: NSObject, MKMapViewDelegate {
//        var parent: MapView
//        
//        init(_ parent: MapView) {
//            self.parent = parent
//        }
//    }
//}
//
//class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    @Published var region: MKCoordinateRegion
//    @Published var locations = [CLLocation]()
//    @Published var tracking: Bool = false
//    private let locationManager = CLLocationManager()
//    
//    override init() {
//        region = MKCoordinateRegion(
//            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
//            latitudinalMeters: 200.0, // 100 yards radius is ~200 meters
//            longitudinalMeters: 200.0
//        )
//        super.init()
//        locationManager.delegate = self
//        locationManager.requestWhenInUseAuthorization()
//        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
//        locationManager.requestLocation()
////        locationManager.startUpdatingLocation()
//    }
//    
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        guard let location = locations.last else { return }
//        region.center = location.coordinate
//        self.locations.append(location)
//        if self.locations.count > 1 {
//            let meters = self.locations[0].distance(from: self.locations[self.locations.count - 1])
//            print("--------")
//            print(meters)
//        }
//        print(location)
//    }
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
//        print("Failed to get location: \(error.localizedDescription)")
//    }
//    func StartStopTracking() {
//        locationManager.requestLocation()
////        if self.tracking {
////            locationManager.stopUpdatingLocation()
////        } else {
////            locationManager.startUpdatingLocation()
////        }
////        self.tracking.toggle()
//        
//    }
//}
//
//struct ContentView: View {
//    @StateObject private var locationManager = LocationManager()
//    @State var tracking: Bool = false
//    var body: some View {
//        ZStack {
//            MapView(region: $locationManager.region)
//            VStack {
//                Spacer()
//                Button("Track Location") {
//                    locationManager.StartStopTracking()
//                }
//            }
//        }
//    }
//}
//
//#Preview {
//    ContentView()
//}
