//
//  BasicExampleView.swift
//  SwiftyChatExample
//
//  Created by Enes Karaosman on 21.10.2020.
//

import SwiftUI
import SwiftyChat
import CloudKit
import MapKit
import CoreLocation

struct ContentView: View {
    @State var messages: [MockMessages.ChatMessageItem] = []
    @State private var hasLoaded = false
    @State var userID: String = ""
    let radiusInMeters: CGFloat = 10000.0
    @StateObject var locationManager = LocationManager()
    
    private let database = CKContainer(identifier: "iCloud.Blurb").publicCloudDatabase

    func fetchItems() {
        DispatchQueue.global(qos: .userInitiated).async {
            while (locationManager.lastLocation == nil) {
            }
            let location = locationManager.lastLocation!
            let predicate: NSPredicate = NSPredicate(format: "distanceToLocation:fromLocation:(location, %@) < %f", location, radiusInMeters)
            let query = CKQuery(recordType: "Post", predicate: predicate)
            // fetch from the database
            database.perform(query, inZoneWith: nil) { (records, error) in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    guard let records = records else {
                        print("Error: Unable to load records!")
                        return
                    }
                    // update the messages array with the fetched records
                    // if the size of messages is not equal to the size of records, then we need to update the messages array
                    if self.messages.count != records.count {
                        self.messages = records.compactMap {
                            MockMessages.ChatMessageItem.init(
                                user: MockMessages.ChatUserItem.init(userName: $0["userID"] as? String ?? "(Unable to load)"),
                                messageKind: ChatMessageKind.text($0["text"] as? String ?? "(Unable to load)"),
                                isSender: ($0["userID"] as? String ?? "(Unable to load)") == self.userID,
                                date: $0["timestamp"] as? Date ?? Date()
                            )
                        }
                        markers.removeAll()
                        for record in records {
                            let MarkerLocation = record["location"] as? CLLocation ?? CLLocation()
                            markers.append(contentsOf: [Marker(location: MapMarker(coordinate: MarkerLocation.coordinate, tint: .orange), name: "\(MarkerLocation.coordinate)")])
                        }
                        self.messages = self.messages.sorted { $0.date < $1.date }
                    }
                    // sort the records by date
                }
            }
        }
    }

    // A function which takes a string and outputs what is between the parentheses
    func getStringBetweenParentheses(string: String) -> String {
        let regex = try! NSRegularExpression(pattern: "\\((.*?)\\)", options: [])
        let range = NSRange(location: 0, length: string.count)
        let matches = regex.matches(in: string, options: [], range: range)
        if let match = matches.first {
            return (string as NSString).substring(with: match.range(at: 1))
        }
        return ""
    }

    func saveItem(message: ChatMessageKind) {
        var messageText = String(message.description)
        messageText = getStringBetweenParentheses(string: messageText)
        let record = CKRecord(recordType: "Post")
        record.setValue(messageText, forKey: "text")
        record.setObject(CLLocation(latitude: locationManager.lastLocation?.coordinate.latitude ?? 0, longitude: locationManager.lastLocation?.coordinate.longitude ?? 0), forKey: "location")
        record.setValue(Date(), forKey: "timestamp")
        record.setValue(userID, forKey: "userID")
        // Save to the database
        database.save(record) { (record, error) in
            if let error = error {
                print(error.localizedDescription)
            } else {
                print("Record saved successfully")
                fetchItems()
            }
        }
    }
    
    // MARK: - InputBarView variables
    @State private var message = ""
    @State private var isEditing = false
//    @State private var regionTwo = MKCoordinateRegion(
//            center: ScaledAnnotationView.usersLocation,latitudinalMeters: 1000, longitudinalMeters: 1000
//        )
    
    struct Marker: Identifiable {
        let id = UUID()
        var location: MapMarker
        let name: String
    }
    @State var markers: [Marker] = []
    
    var body: some View {
        VStack {
            Map(coordinateRegion: $locationManager.region,
                showsUserLocation: true,
                annotationItems: markers) { marker in
                    marker.location }.edgesIgnoringSafeArea(.all)
            ZStack {
                // Colored background
                Color.gray.edgesIgnoringSafeArea(.all)
                Text("Showing posts within \(Int(radiusInMeters / 1000))km of you")
                .foregroundColor(Color.white)
                .font(.headline)
                .scaledToFit()
            }
            // Get Screen Size
            .frame(height: UIScreen.main.bounds.height / 25)
            chatView
        }
        .onAppear {
            fetchItems()
            Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                fetchItems()
            }
            userID = UserDefaults.standard.string(forKey: "userId") ?? ""
            if userID == "" {
                let userId = UUID().uuidString
                UserDefaults.standard.set(userId, forKey: "userId")
            }
        }
    }
    
    private var chatView: some View {
        // A label to show the current state of the chat
        ChatView<MockMessages.ChatMessageItem, MockMessages.ChatUserItem>(messages: $messages) {

        BasicInputView(
            message: $message,
            isEditing: $isEditing,
            placeholder: "Type something",
            onCommit: { messageKind in
                self.messages.append(
                    .init(user: MockMessages.sender, messageKind: messageKind, isSender: true)
                )
                // Convert CustomStringConvertible to String
                self.saveItem(message: messageKind)
            }
        )
        .padding(8)
        .padding(.bottom, isEditing ? 0 : 8)
        .accentColor(.blue)
        .background(Color.primary.colorInvert())
        .animation(.linear)
        .embedInAnyView()
        }
        // ▼ Optional, Present context menu when cell long pressed
        .messageCellContextMenu { message -> AnyView in
            switch message.messageKind {
            case .text(let text):
                return Button(action: {
                    print("Copy Context Menu tapped!!")
                    UIPasteboard.general.string = text
                }) {
                    Text("Copy")
                    Image(systemName: "doc.on.doc")
                }.embedInAnyView()
            default:
                // If you don't want to implement contextMenu action
                // for a specific case, simply return EmptyView like below;
                return EmptyView().embedInAnyView()
            }
        }
        // ▼ Required
        .environmentObject(ChatMessageCellStyle.init())
        .navigationBarTitle("Basic")
        .listStyle(PlainListStyle())
    }

//    struct CurrentUsersAnnotation: Identifiable {
//        let id = UUID() // Always unique on map
//    }

//    struct ScaledAnnotationView: View {
//        let annotations = [CurrentUsersAnnotation()]
////        static let usersLocation = CLLocationCoordinate2D(latitude: 52.0929779694589, longitude: 5.084964426384347)
////        @State private var region = MKCoordinateRegion(
////                center: ScaledAnnotationView.usersLocation,latitudinalMeters: 1000, longitudinalMeters: 1000
////            )
//        @StateObject var locationManager = LocationManager()
//        var body: some View {
//            //Get the size of the frame for scale
//            GeometryReader{ geo in
//                Map(coordinateRegion: $locationManager.region,
//                    showsUserLocation: true,
//                    annotationItems: markers) { marker in
//                        marker.location }.edgesIgnoringSafeArea(.all)
//                Map(coordinateRegion: $locationManager.region,
//                    showsUserLocation: true,
//                    annotationItems: markers) { marker in
//                    MapAnnotation(coordinate: locationManager.lastLocation?.coordinate ?? CLLocationCoordinate2D()) {
//                            //Size per kilometer or any unit, just change the converted unit.
//                        let kilometerSize = (geo.size.height/locationManager.region.spanLatitude.converted(to: .kilometers).value)
//                        Circle()
//                            .fill(Color.red.opacity(0.5))
//                        //Keep it a circle
//                            .frame(width: kilometerSize, height: kilometerSize)
//                    }
//                }
//            }
//        }
//    }
}
extension MKCoordinateRegion{
    ///Identify the length of the span in meters north to south
    var spanLatitude: Measurement<UnitLength>{
        let loc1 = CLLocation(latitude: center.latitude - span.latitudeDelta * 0.5, longitude: center.longitude)
        let loc2 = CLLocation(latitude: center.latitude + span.latitudeDelta * 0.5, longitude: center.longitude)
        let metersInLatitude = loc1.distance(from: loc2)
        return Measurement(value: metersInLatitude, unit: UnitLength.meters)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
