//
//  RemoteImage.swift
//
//  Created by Hovik Melikyan on 17.04.23.
//

import SwiftUI


struct RemoteImage<P: View, I: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> I
    @ViewBuilder let placeholder: (Error?) -> P

    @State private var uiImage: UIImage?
    @State private var error: Error?

    var body: some View {
        ZStack {
            if let image = uiImage.map({ Image(uiImage: $0) }) {
                content(image)
            }
            else if let error {
                placeholder(error)
            }
            else {
                placeholder(nil)
            }
        }
        .onChange(of: url, initial: true) { oldValue, newValue in
            uiImage = nil
            error = nil
            if let newValue {
                Task {
                    do {
                        self.uiImage = try await ImageCache.request(newValue)
                    }
                    catch {
                        self.error = error
                    }
                }
            }
        }
    }
}


#Preview {
    let url = URL(string: "https://images.unsplash.com/photo-1513051265668-0ebab31671ae")!

    return RemoteImage(url: url) { image in
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
    } placeholder: { error in
        Text(error?.localizedDescription ?? "LOADING...")
            .font(.caption)
            .padding()
    }
}
