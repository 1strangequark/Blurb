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
    @StateObject var locationManager = LocationManager()
    @State private var hasLoaded = false
    @State var userID: String = ""
    
    private let database = CKContainer(identifier: "iCloud.Blurb").publicCloudDatabase

    func fetchItems() {
        let location = locationManager.lastLocation!
        let radiusInKilometers:CGFloat = 1;
        let predicate: NSPredicate = NSPredicate(format: "distanceToLocation:fromLocation:(location, %@) < %f", location, radiusInKilometers)
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
                self.messages = records.compactMap { 
                    MockMessages.ChatMessageItem.init(
                        user: MockMessages.ChatUserItem.init(userName: $0["userID"] as? String ?? "(Unable to load)"),
                        messageKind: ChatMessageKind.text($0["text"] as? String ?? "(Unable to load)"),
                        isSender: ($0["userID"] as? String ?? "(Unable to load)") == self.userID,
                        date: $0["timestamp"] as? Date ?? Date()
                    ) 
                }
                for record in records {
                    let location = record["location"] as? CLLocation ?? CLLocation()
                    markers.append(contentsOf: [Marker(location: MapMarker(coordinate: location.coordinate, tint: .orange), name: "Test Marker")])
                }
                // sort the records by date
                self.messages = self.messages.sorted { $0.date < $1.date }
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
            }
        }
    }
    
    // MARK: - InputBarView variables
    @State private var message = ""
    @State private var isEditing = false
    
    struct Marker: Identifiable {
        let id = UUID()
        var location: MapMarker
        let name: String
    }
    @State var markers: [Marker] = []
    
    var body: some View {
        ZStack {
            VStack {
                Map(coordinateRegion: $locationManager.region,
                    showsUserLocation: true,
                    annotationItems: markers) { marker in
                        marker.location }.edgesIgnoringSafeArea(.all)
                chatView
            }
            .onChange(of: locationManager.lastLocation) { _ in
                if !hasLoaded {
                    hasLoaded = true
                    fetchItems()
                }
            }
            .onAppear {
                // Create a unique user id and store in UserDefaults
                userID = UserDefaults.standard.string(forKey: "userId") ?? ""
                if userID == "" {
                    let userId = UUID().uuidString
                    UserDefaults.standard.set(userId, forKey: "userId")
                }
            }
            VStack {
                Text(" ")
                Text("Latitude: " +  String(round(1000 * (Float("\(locationManager.lastLocation?.coordinate.latitude ?? 0)") ?? -1.0)) / 1000))
                Text("Longitude: " +  String(round(1000 * (Float("\(locationManager.lastLocation?.coordinate.longitude ?? 0)") ?? -1.0)) / 1000))
                Spacer()
            }
            .font(.system(.largeTitle, design: .rounded))
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
