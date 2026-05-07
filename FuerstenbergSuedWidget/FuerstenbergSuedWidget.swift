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
    static let topCropRatio: CGFloat = 0.055
    static let bottomCropRatio: CGFloat = 0.065
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
    @Environment(\.widgetFamily) private var family
    let entry: FuerstenbergSuedEntry

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                imageContent
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                labelBadge
                    .fixedSize()
                    .padding(.leading, badgeInsets(in: geometry.size).leading)
                    .padding(.top, badgeInsets(in: geometry.size).top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(FuerstenbergSuedWidgetConfiguration.deepLinkURL)
        .modifier(FuerstenbergSuedWidgetBackground())
    }

    @ViewBuilder
    private var imageContent: some View {
        ZStack {
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
        }
    }

    @ViewBuilder
    private var labelBadge: some View {
        switch family {
        case .systemSmall:
            Text("Sued")
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.28), in: Capsule())
                .foregroundColor(.white)
        case .systemMedium, .systemLarge:
            HStack(spacing: 5) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 10, weight: .semibold))
                ViewThatFits {
                    Text("Fuerstenberg Sued")
                    Text("Webcam Sued")
                    Text("Sued")
                }
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.black.opacity(0.28), in: Capsule())
            .foregroundColor(.white)
        default:
            EmptyView()
        }
    }

    private func badgeInsets(in size: CGSize) -> EdgeInsets {
        let horizontalInset = max(18, size.width * horizontalInsetRatio)
        let verticalInset = max(18, size.height * verticalInsetRatio)

        return EdgeInsets(top: verticalInset, leading: horizontalInset, bottom: 0, trailing: 0)
    }

    private var horizontalInsetRatio: CGFloat {
        switch family {
        case .systemSmall:
            return 0.05
        case .systemMedium, .systemLarge:
            return 0.04
        default:
            return 0.04
        }
    }

    private var verticalInsetRatio: CGFloat {
        switch family {
        case .systemSmall:
            return 0.05
        case .systemMedium, .systemLarge:
            return 0.045
        default:
            return 0.045
        }
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
        .contentMarginsDisabled()
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
        let croppedImage = cropOverlayBars(from: image) ?? image
        guard let jpegData = croppedImage.jpegData(compressionQuality: 0.82) else {
            return nil
        }

        return jpegData
    }

    private func cropOverlayBars(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let topInset = height * FuerstenbergSuedWidgetConfiguration.topCropRatio
        let bottomInset = height * FuerstenbergSuedWidgetConfiguration.bottomCropRatio
        let cropHeight = height - topInset - bottomInset

        guard cropHeight > 0 else {
            return nil
        }

        let cropRect = CGRect(x: 0, y: topInset, width: width, height: cropHeight).integral
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
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
