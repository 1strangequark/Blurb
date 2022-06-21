//
//  BasicExampleView.swift
//  SwiftyChatExample
//
//  Created by Enes Karaosman on 21.10.2020.
//

import SwiftUI
import SwiftyChat
import GSPlayer
import Kingfisher
import SwiftUIEKtensions
import VideoPlayer
import WrappingHStack

struct ContentView: View {
    
    @State var messages: [MockMessages.ChatMessageItem] = []
    @StateObject var locationManager = LocationManager()
    var userLatitude: String {
        return "\(locationManager.lastLocation?.coordinate.latitude ?? 0)"
    }
    
    var userLongitude: String {
        return "\(locationManager.lastLocation?.coordinate.longitude ?? 0)"
    }
    
    // MARK: - InputBarView variables
    @State private var message = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Latitude: " +  String(round(1000 * (Float(userLatitude) ?? -1.0)) / 1000))
                Text("Longitude: " +  String(round(1000 * (Float(userLongitude) ?? -1.0)) / 1000))
            }
            chatView
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
