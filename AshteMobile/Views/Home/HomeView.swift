//
//  HomeView.swift
//  AshteMobile
//
//  Created for AshteMobile
//  100% Clean Pro UI with Notification Name Fix ⚡️
//

import SwiftUI
import NimbleViews
import AltSourceKit
import Foundation
import UIKit
import Combine
import CoreData

// MARK: - Global Lock
class HomeGlobalLock {
    static var isSigningActive = false
}

// MARK: - Tab Categories
enum HomeCategoryTab: String, CaseIterable, Identifiable {
    case all = "All"
    case apps = "Apps"
    case games = "Games"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .all: return "All"
        case .apps: return "Apps"
        case .games: return "Games"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "sparkles"
        case .apps: return "square.grid.2x2.fill"
        case .games: return "gamecontroller.fill"
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .all: return AshteTheme.primary
        case .apps: return AshteTheme.ocean
        case .games: return AshteTheme.sunset
        }
    }
    
    var color: Color {
        switch self {
        case .all: return AshteTheme.violet
        case .apps: return AshteTheme.cyan
        case .games: return AshteTheme.pink
        }
    }
}

// MARK: - Models
struct AshteHomeAppResponse: Codable {
    let name: String?
    let apps: [AshteHomeAppModel]
}

struct AshteHomeAppModel: Codable, Identifiable {
    var id: Int { idNumber }
    let idNumber: Int
    let name: String
    let version: String?
    let category: String?
    let type: String? 
    let iconURL: String?
    let size: String?
    let developerName: String?
    let bundleIdentifier: String?
    let download_url: String
    let descriptionText: String? 
    
    var stringID: String { return "\(idNumber)" }
    var downloadURLObject: URL? { return URL(string: download_url) }
    
    enum CodingKeys: String, CodingKey {
        case idNumber = "id"
        case name, version, category, type, iconURL, size, developerName, bundleIdentifier, download_url
        case descriptionText = "description"
    }

    var fullImageURL: URL? {
        guard let img = iconURL else { return nil }
        if img.hasPrefix("http") { return URL(string: img) }
        return URL(string: "https://ashtemobile.site/\(img)")
    }
}

// MARK: - Banner Model
struct SocialBanner: Identifiable {
    let id = UUID()
    let imageURL: URL?
    let destinationURL: URL?
}

// MARK: - Main Home View
struct HomeView: View {
    @Environment(\.openURL) var openURL
    @State private var appsList: [AshteHomeAppModel] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedTab: HomeCategoryTab = .all
    
    @State private var _selectedInstallAppPresenting: AnyApp?
    @AppStorage("AshteMobile.installationMethod") private var installationMethod: Int = 0
    
    @FetchRequest(
        entity: Signed.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
        animation: .snappy
    ) private var _signedApps: FetchedResults<Signed>
    
    private var filteredApps: [AshteHomeAppModel] {
        appsList.filter { app in
            let matchesSearch = searchText.isEmpty || app.name.localizedCaseInsensitiveContains(searchText)
            guard matchesSearch else { return false }
            
            let appType = (app.type ?? "").lowercased()
            switch selectedTab {
            case .all: return true
            case .apps: return appType == "apps"
            case .games: return appType == "games"
            }
        }
    }
    
    @State private var _currentBannerIndex = 0
    private let bannerTimer = Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()
    
    let staticBanners = [
        SocialBanner(
            imageURL: URL(string: "https://ashtemobile.site/img/t.png"),
            destinationURL: URL(string: "https://t.me/ashtemobile")
        ),
        SocialBanner(
            imageURL: URL(string: "https://ashtemobile.site/img/i.png"),
            destinationURL: URL(string: "https://instagram.com/ashtemobile")
        )
    ]
    
    var body: some View {
        NBNavigationView(.localized("Home")) {
            ZStack {
                AshteBackground()
                
                if isLoading && appsList.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(AshteTheme.pink)
                        Text(.localized("Loading..."))
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            
                            if searchText.isEmpty {
                                TabView(selection: $_currentBannerIndex) {
                                    ForEach(staticBanners.indices, id: \.self) { index in
                                        let banner = staticBanners[index]
                                        Button {
                                            if let url = banner.destinationURL {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            AsyncImage(url: banner.imageURL) { phase in
                                                if let image = phase.image {
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                } else if phase.error != nil {
                                                    Rectangle().fill(Color(uiColor: .secondarySystemBackground))
                                                        .overlay(Image(systemName: "photo.fill").foregroundColor(.secondary))
                                                } else {
                                                    Rectangle().fill(Color(uiColor: .secondarySystemBackground))
                                                        .overlay(ProgressView())
                                                }
                                            }
                                            .frame(height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                            .padding(.horizontal, 12)
                                        }
                                        .buttonStyle(.plain)
                                        .tag(index)
                                    }
                                }
                                .frame(height: 230)
                                .tabViewStyle(.page(indexDisplayMode: .always))
                                .onReceive(bannerTimer) { _ in
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        _currentBannerIndex = (_currentBannerIndex + 1) % staticBanners.count
                                    }
                                }
                                .padding(.top, 10)
                            }
                            
                            AshteChipBar(
                                options: HomeCategoryTab.allCases.map { $0.title },
                                selection: Binding(
                                    get: { selectedTab.title },
                                    set: { newTitle in
                                        if let tab = HomeCategoryTab.allCases.first(where: { $0.title == newTitle }) {
                                            selectedTab = tab
                                        }
                                    }
                                )
                            )
                            
                            if !filteredApps.isEmpty {
                                VStack(spacing: 6) {
                                    AshteSectionTitle(
                                        title: selectedTab == .all ? .localized("Recently Updated") : selectedTab.title,
                                        count: filteredApps.count,
                                        gradient: selectedTab.gradient
                                    )
                                    .padding(.horizontal, 20)
                                    
                                    VStack(spacing: 0) {
                                        ForEach(filteredApps) { app in
                                            NavigationLink(destination: AshteHomeAppDetailView(app: app, onDownloadComplete: { handleAutoSign(for: app) })) {
                                                AshteHomeAppCell(app: app, onDownloadComplete: { handleAutoSign(for: app) })
                                                    .padding(.horizontal, 20)
                                                    .padding(.vertical, 12)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            if app.idNumber != filteredApps.last?.idNumber {
                                                Divider()
                                                    .padding(.leading, 89)
                                            }
                                        }
                                    }
                                }
                            } else if !searchText.isEmpty || !isLoading {
                                AshteHomeEmptyView()
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: .localized("Search apps..."))
            .refreshable {
                await loadRemoteApps()
            }
            .ashteTopActions()
        }
        .task {
            await loadRemoteApps()
        }
    }
    
    @Namespace private var tabAnimation
    
    private func handleAutoSign(for app: AshteHomeAppModel) {
        if installationMethod == 1 { return }
        
        AshteAutoSigner.signAfterDownload(id: app.stringID, appName: app.name) { result in
            if case .signed = result {
                NotificationCenter.default.post(name: Notification.Name("AshteMobile.ShowSignSuccess"), object: app.name)
            }
        }
    }
    
    private func loadRemoteApps() async {
        isLoading = true
        guard let url = URL(string: "https://ashtemobile.site/Ashtemobile.json") else {
            isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(AshteHomeAppResponse.self, from: data)
            DispatchQueue.main.async {
                self.appsList = decoded.apps
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
}

// MARK: - Empty State View
struct AshteHomeEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(AshteTheme.candy)
            Text(.localized("No Applications Found"))
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
            Text(.localized("Try selecting another category or searching again."))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Sleek App Cell
struct AshteHomeAppCell: View {
    let app: AshteHomeAppModel
    var onDownloadComplete: () -> Void
    
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var downloadProgress: Double = 0
    @State private var cancellable: AnyCancellable?
    @State private var hasTriggeredDownloadAction = false
    
    private var _subtitle: String {
        let version = app.version ?? "1.0"
        let firstLine = (app.descriptionText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first ?? ""
        return firstLine.isEmpty ? version : "\(version) • \(firstLine)"
    }

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: app.fullImageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(UIColor.tertiarySystemGroupedBackground)
            }
            .frame(width: 53, height: 53)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(_subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(app.category ?? app.type ?? "apps")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 10)
            
            ZStack {
                if let currentDownload = downloadManager.getDownload(by: app.stringID) {
                    ZStack {
                        Circle()
                            .trim(from: 0, to: downloadProgress)
                            .stroke(AshteTheme.primary, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 32, height: 32)
                            .animation(.smooth, value: downloadProgress)

                        Image(systemName: downloadProgress >= 0.75 ? "archivebox.fill" : "stop.fill")
                            .foregroundStyle(.tint)
                            .font(.system(size: 11, weight: .black))
                    }
                    .onTapGesture {
                        if downloadProgress <= 0.75 {
                            downloadManager.cancelDownload(currentDownload)
                        }
                    }
                } else {
                    Button(action: { triggerDownload() }) {
                        Text(.localized("Get"))
                    }
                    .buttonStyle(AshteGradientButtonStyle(
                        gradient: app.type == "games" ? AshteTheme.sunset : AshteTheme.primary,
                        shadowColor: app.type == "games" ? AshteTheme.pink : AshteTheme.violet
                    ))
                }
            }
        }
        .onAppear(perform: setupObserver)
        .onDisappear { cancellable?.cancel() }
        .onChange(of: downloadManager.downloads.count) { _ in
            let isCurrentlyDownloading = downloadManager.getDownload(by: app.stringID) != nil
            if isCurrentlyDownloading {
                setupObserver()
                hasTriggeredDownloadAction = false 
            } else if downloadProgress >= 0.98 && !hasTriggeredDownloadAction {
                hasTriggeredDownloadAction = true 
                onDownloadComplete()
            }
        }
    }
    
    // 💡 ئەوەتە ئێرەمان چاککرد تا ناوەکەی بنێرێت بۆ شاشەکە
    private func triggerDownload() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        if let dlURL = app.downloadURLObject {
            AshteAutoSigner.markDownloadStart(id: app.stringID)
            _ = DownloadManager.shared.startDownload(
                from: dlURL, 
                id: app.stringID,
                appName: app.name,            // 💡 دڵنیابە ئەمە هەیە
                appIconURL: app.fullImageURL  // 💡 دڵنیابە ئەمە هەیە
            )
        }
    }
    
    private func setupObserver() {
        cancellable?.cancel()
        guard let download = downloadManager.getDownload(by: app.stringID) else {
            downloadProgress = 0
            return
        }
        downloadProgress = download.overallProgress
        let publisher = Publishers.CombineLatest(download.$progress, download.$unpackageProgress)
        cancellable = publisher.sink { _, _ in downloadProgress = download.overallProgress }
    }
}

// MARK: - Premium Detail View
struct AshteHomeAppDetailView: View {
    let app: AshteHomeAppModel
    var onDownloadComplete: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var downloadProgress: Double = 0
    @State private var cancellable: AnyCancellable?
    @State private var hasTriggeredDownloadAction = false 
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Blurred header made from the app icon
                GeometryReader { proxy in
                    let minY = proxy.frame(in: .global).minY
                    AsyncImage(url: app.fullImageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(UIColor.systemGray4)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height + (minY > 0 ? minY : 0))
                    .clipped()
                    .offset(y: minY > 0 ? -minY : 0)
                    .blur(radius: 40, opaque: true)
                    .overlay(Color.black.opacity(0.15))
                }
                .frame(height: 230)
                
                // Icon + name + category + Get
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: app.fullImageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(UIColor.secondarySystemBackground)
                    }
                    .frame(width: 106, height: 106)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(app.category ?? app.type ?? "apps")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                        
                        if downloadManager.getDownload(by: app.stringID) != nil {
                            HStack(spacing: 10) {
                                ProgressView(value: min(max(downloadProgress, 0), 1))
                                    .tint(Color.accentColor)
                                Text("\(Int(downloadProgress * 100))%")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.accentColor)
                                    .monospacedDigit()
                            }
                            .padding(.top, 6)
                        } else {
                            Button(action: { triggerDownload() }) {
                                Text(.localized("Get"))
                            }
                            .buttonStyle(AshteGradientButtonStyle())
                            .padding(.top, 4)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                Divider().padding(.horizontal, 16)
                
                // Version + size
                HStack(spacing: 12) {
                    AshteDetailChip(
                        icon: "tag",
                        text: app.version ?? "1.0",
                        tint: Color.accentColor,
                        filled: true
                    )
                    AshteDetailChip(
                        icon: "archivebox",
                        text: app.size ?? "N/A",
                        tint: .primary,
                        filled: false
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Divider().padding(.horizontal, 16)
                
                // Description
                VStack(alignment: .leading, spacing: 10) {
                    Text(.localized("Description"))
                        .font(.system(size: 26, weight: .bold))
                    
                    Text(app.descriptionText ?? "No description available for \(app.name).")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                
                Divider().padding(.horizontal, 16)
                
                // Information
                VStack(alignment: .leading, spacing: 0) {
                    Text(.localized("Information"))
                        .font(.system(size: 26, weight: .bold))
                        .padding(.bottom, 10)
                    
                    AshteInfoRow(title: .localized("Developer"), value: app.developerName ?? "AshteMobile")
                    AshteInfoRow(title: .localized("Identifier"), value: app.bundleIdentifier ?? "-")
                    AshteInfoRow(title: .localized("Category"), value: app.category ?? app.type ?? "-")
                    AshteInfoRow(title: .localized("Size"), value: app.size ?? "-", showsDivider: false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .padding(.bottom, 80)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .background(AshteBackground())
        .navigationBarHidden(true)
        .overlay(alignment: .top) {
            HStack(spacing: 12) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                
                Spacer()
                
                // Share only the app name + the website, never the real download link
                ShareLink(item: "\(app.name)\nhttps://ashtemobile.site") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, _topSafeAreaInset)
        }
        .onAppear(perform: setupObserver)
        .onDisappear { cancellable?.cancel() }
        .onChange(of: downloadManager.downloads.count) { _ in
            let isCurrentlyDownloading = downloadManager.getDownload(by: app.stringID) != nil
            if isCurrentlyDownloading {
                setupObserver()
                hasTriggeredDownloadAction = false
            } else if downloadProgress >= 0.98 && !hasTriggeredDownloadAction {
                hasTriggeredDownloadAction = true 
                onDownloadComplete()
            }
        }
    }
    
    private var _topSafeAreaInset: CGFloat {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        return scene?.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.top ?? 50
    }
    
    // 💡 لێرەشدا چاکمان کرد تا ناوەکەی بنێرێت بۆ شاشەکە
    private func triggerDownload() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        if let dlURL = app.downloadURLObject {
            AshteAutoSigner.markDownloadStart(id: app.stringID)
            _ = DownloadManager.shared.startDownload(
                from: dlURL, 
                id: app.stringID,
                appName: app.name,            // 💡 دڵنیابە ئەمە هەیە
                appIconURL: app.fullImageURL  // 💡 دڵنیابە ئەمە هەیە
            )
        }
    }
    
    private func setupObserver() {
        cancellable?.cancel()
        guard let download = downloadManager.getDownload(by: app.stringID) else {
            downloadProgress = 0
            return
        }
        downloadProgress = download.overallProgress
        let publisher = Publishers.CombineLatest(download.$progress, download.$unpackageProgress)
        cancellable = publisher.sink { _, _ in downloadProgress = downloadManager.getDownload(by: app.stringID)?.overallProgress ?? 0 }
    }
}

// MARK: - Modern Info Card
struct AshteInfoCard: View {
    let title: String
    let value: String
    let icon: String
    var gradient: LinearGradient = AshteTheme.primary
    
    var body: some View {
        VStack(spacing: 8) {
            AshteIconBadge(systemName: icon, gradient: gradient, size: 34)
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .ashteCard(cornerRadius: 20)
    }
}

// MARK: - Detail helpers
struct AshteDetailChip: View {
    let icon: String
    let text: String
    var tint: Color
    var filled: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(filled ? tint.opacity(0.15) : Color(UIColor.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AshteInfoRow: View {
    let title: String
    let value: String
    var showsDivider: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                Spacer(minLength: 12)
                Text(value)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 14)
            
            if showsDivider {
                Divider()
            }
        }
    }
}
