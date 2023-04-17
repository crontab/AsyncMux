//
//  RemoteImage.swift
//  AsyncMux
//
//  Created by Hovik Melikyan on 17.04.23.
//

import SwiftUI
import AsyncMux


struct RemoteImage<P: View, I: View>: View {

    let url: URL?
    let content: (Image) -> I
    let placeholder: () -> P

    @State private var contentResult: I?

    @ViewBuilder
    var body: some View {
        if let contentResult {
            contentResult
        }
        else {
            placeholder()
                .task {
                    guard let url else { return }
                    guard let localURL = try? await AsyncMedia.shared.request(url: url) else { return }
                    guard let uiImage = UIImage(contentsOfFile: localURL.path) else { return }
                    contentResult = content(Image(uiImage: uiImage))
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
        } placeholder: {
            Text("LOADING...")
                .font(.caption)
        }
    }
}
