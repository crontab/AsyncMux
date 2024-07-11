//
//  RemoteImage.swift
//
//  Created by Hovik Melikyan on 17.04.23.
//

import SwiftUI
import AsyncMux


struct RemoteImage<P: View, I: View>: View {

    let url: URL?
    @ViewBuilder let content: (Image) -> I
    @ViewBuilder let placeholder: (Error?) -> P

    @State private var result: Image?
    @State private var error: Error?

    var body: some View {
        if let result {
            content(result)
        }

        else if let error {
            placeholder(error)
        }

        else if let image = url.flatMap({ ImageCache.loadFromMemory($0) }) {
            content(image)
                .task {
                    result = image // the view will be updated twice; is there a better way?
                }
        }

        else {
            placeholder(nil)
                .task {
                    guard let url else { return }
                    do {
                        result = try await ImageCache.request(url)
                    }
                    catch {
                        self.error = error
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
            .padding(24)
    }
}
