//
//  FuerstenbergSuedWidget.swift
//  FuerstenbergSuedWidget
//
//  Created by Michael Sommer on 07.05.26.
//

import SwiftUI
import UIKit
import WidgetKit
import ImageIO

private enum FuerstenbergSuedWidgetConfiguration {
    static let kind = "FuerstenbergSuedWidget"
    static let displayName = "Fuerstenberg Sued"
    static let description = "Zeigt das aktuelle Webcam-Bild vom Startplatz Fuerstenberg Sued."
    static let imageURL = URL(string: "https://baar-flieger.de/webcams/sued_current.php")!
    static let deepLinkURL = URL(string: "pilotencockpit://webcam/sued")!
    static let cacheFileName = "fuerstenberg-sued-current.jpg"
    static let maxPixelDimension = 1100
}

struct FuerstenbergSuedEntry: TimelineEntry {
    let date: Date
    let imageData: Data?
    let isPlaceholder: Bool

    var image: UIImage? {
        guard let imageData else {
            return nil
        }

        return UIImage(data: imageData)
    }
}

struct FuerstenbergSuedProvider: TimelineProvider {
    func placeholder(in context: Context) -> FuerstenbergSuedEntry {
        FuerstenbergSuedEntry(date: Date(), imageData: nil, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (FuerstenbergSuedEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }

        FuerstenbergSuedImageStore.shared.loadCurrentEntry(completion: completion)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FuerstenbergSuedEntry>) -> Void) {
        FuerstenbergSuedImageStore.shared.loadCurrentEntry { entry in
            let refreshDate = Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }
}

struct FuerstenbergSuedWidgetEntryView: View {
    let entry: FuerstenbergSuedEntry

    var body: some View {
        ZStack {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.gray.opacity(0.85), Color.gray.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                    Text(FuerstenbergSuedWidgetConfiguration.displayName)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .widgetURL(FuerstenbergSuedWidgetConfiguration.deepLinkURL)
        .modifier(FuerstenbergSuedWidgetBackground())
    }
}

struct FuerstenbergSuedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: FuerstenbergSuedWidgetConfiguration.kind,
            provider: FuerstenbergSuedProvider()
        ) { entry in
            FuerstenbergSuedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(FuerstenbergSuedWidgetConfiguration.displayName)
        .description(FuerstenbergSuedWidgetConfiguration.description)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct FuerstenbergSuedWidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(.fill.tertiary, for: .widget)
        } else {
            content
        }
    }
}

private final class FuerstenbergSuedImageStore {
    static let shared = FuerstenbergSuedImageStore()

    private init() {}

    func loadCurrentEntry(completion: @escaping (FuerstenbergSuedEntry) -> Void) {
        var request = URLRequest(url: FuerstenbergSuedWidgetConfiguration.imageURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data, let processedData = self.downsampledImageData(from: data) {
                self.store(processedData)
                completion(FuerstenbergSuedEntry(date: Date(), imageData: processedData, isPlaceholder: false))
                return
            }

            let cachedData = self.loadCachedData()
            completion(FuerstenbergSuedEntry(date: Date(), imageData: cachedData, isPlaceholder: cachedData == nil))
        }.resume()
    }

    private func store(_ data: Data) {
        guard let cacheURL = cacheURL else {
            return
        }

        try? data.write(to: cacheURL, options: .atomic)
    }

    private func loadCachedData() -> Data? {
        guard let cacheURL = cacheURL else {
            return nil
        }

        return try? Data(contentsOf: cacheURL)
    }

    private func downsampledImageData(from data: Data) -> Data? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: FuerstenbergSuedWidgetConfiguration.maxPixelDimension
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        guard let jpegData = image.jpegData(compressionQuality: 0.82) else {
            return nil
        }

        return jpegData
    }

    private var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(FuerstenbergSuedWidgetConfiguration.cacheFileName)
    }
}

#Preview(as: .systemSmall) {
    FuerstenbergSuedWidget()
} timeline: {
    FuerstenbergSuedEntry(date: .now, imageData: nil, isPlaceholder: true)
}
