//
//  RemoteImage.swift
//
//  Created by Hovik Melikyan on 17.04.23.
//

import SwiftUI
import AsyncMux


struct RemoteImage<P: View, I: View>: View {
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping (Error?) -> P) {
        self.model = url.map { Model(url: $0) }
        self.content = content
        self.placeholder = placeholder
    }
    
    private let model: Model?
    @ViewBuilder private let content: (Image) -> I
    @ViewBuilder private let placeholder: (Error?) -> P
    
    var body: some View {
        if let image = model?.image {
            content(image)
        }
        else if let error = model?.error {
            placeholder(error)
        }
        else {
            placeholder(nil)
        }
    }
    
    
    @MainActor
    @Observable final class Model {
        var image: Image?
        var error: Error?
        
        init(url: URL) {
            image = ImageCache.loadFromMemory(url)
            if image == nil {
                Task {
                    do {
                        self.image = try await ImageCache.request(url)
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
