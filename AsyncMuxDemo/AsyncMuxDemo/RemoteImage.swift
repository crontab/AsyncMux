//
//  RemoteImage.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 17.04.23.
//

import SwiftUI
import AsyncMux


// TODO: Add LRU cache? Unless the OS already does it


struct RemoteImage<P: View, I: View>: View {

    let url: URL
    let content: (Image) -> I
    let placeholder: (Error?) -> P

    @State private var result: Image?
    @State private var error: Error?

    @ViewBuilder
    var body: some View {
        if let result {
            content(result)
        }

        else if let error {
            placeholder(error)
        }

        else if let localURL = AsyncMedia.cachedValue(url: url) {
            if let uiImage = UIImage(contentsOfFile: localURL.path) {
                let image = Image(uiImage: uiImage)
                content(image)
                    .task {
                        result = image // will be updated twice; is there a better way?
                    }
            }
            else { // cached file is damaged, normally shouldn't happen
                placeholder(nil)
            }
        }

        else {
            placeholder(nil)
                .task {
                    do {
                        let localURL = try await AsyncMedia.shared.request(url: url)
                        guard let uiImage = UIImage(contentsOfFile: localURL.path) else { return }
                        result = Image(uiImage: uiImage)
                    }
                    catch {
                        self.error = error
                    }
                }
        }
    }
}


struct RemoteImage_Previews: PreviewProvider {
    private static let url = URL(string: "https://images.unsplash.com/photo-1513051265668-0ebab31671ae")!

    static var previews: some View {
        RemoteImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .ignoresSafeArea()
        } placeholder: { error in
            Text(error?.localizedDescription ?? "LOADING...")
                .font(.caption)
                .padding(24)
        }
    }
}
