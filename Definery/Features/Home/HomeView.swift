//
//  HomeView.swift
//  Definery
//
//  Created by Anthony on 3/1/26.
//

import SwiftUI
import ScreenStateKit
import WordFeature

struct HomeView: View {
    @State private var viewState: HomeViewState
    @State private var viewStore: HomeViewStore
    @State private var shimmerPhase: CGFloat = 0

    init(viewStore: HomeViewStore, viewState: HomeViewState) {
        self._viewStore = State(initialValue: viewStore)
        self._viewState = State(initialValue: viewState)
    }

    var body: some View {
        NavigationStack {
            contentBody
                .navigationTitle("Definery")
        }
        .onShowError($viewState.displayError)
        .task {
            await viewStore.binding(state: viewState)
            viewStore.receive(action: .loadWords)
        }
        .onChange(of: viewState.snapshot.isPlaceholder, initial: true) { _, isPlaceholder in
            if isPlaceholder {
                shimmerPhase = 0
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            } else {
                withAnimation(.none) {
                    shimmerPhase = 0
                }
            }
        }
    }

    var contentBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            LanguageSegmentedPicker(
                selected: viewState.snapshot.selectedLanguage
            ) { language in
                viewStore.receive(action: .selectLanguage(language))
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)

            content
        }
    }
}

// MARK: - Components

extension HomeView {
    @ViewBuilder
    private var content: some View {
        if viewState.hasError {
            errorState
        } else if viewState.snapshot.isPlaceholder || viewState.hasWords {
            wordList
        } else {
            emptyState
        }
    }

    private var wordList: some View {
        List {
            ForEach(viewState.snapshot.words) { word in
                WordCardView(word: word)
                    .listRowSeparator(.hidden)
                    .placeholder(viewState.snapshot)
                    .modifier(PhaseShimmerModifier(phase: shimmerPhase, isActive: viewState.snapshot.isPlaceholder))
            }

            loadMoreSection
        }
        .listStyle(.plain)
        .refreshable {
            await viewStore.isolatedReceive(action: .refresh)
        }
        .disabled(viewState.snapshot.isPlaceholder)
    }

    @ViewBuilder
    private var loadMoreSection: some View {
        if !viewState.snapshot.words.isEmpty
            && viewState.canShowLoadmore
            && !viewState.snapshot.isPlaceholder {
            RMLoadmoreView(states: viewState)
                .id(UUID())
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .onAppear {
                    viewStore.receive(action: .loadMore)
                }
        }
    }

    private var emptyState: some View {
        GeometryReader { geometry in
            ScrollView {
                ContentUnavailableView(
                    String(localized: "empty.title", table: "Home"),
                    systemImage: "book.closed",
                    description: Text("empty.description", tableName: "Home")
                )
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
    }

    private var errorState: some View {
        GeometryReader { geometry in
            ScrollView {
                ContentUnavailableView {
                    Label(String(localized: "error.title", table: "Home"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(viewState.displayError?.errorDescription ?? "")
                } actions: {
                    Button(String(localized: "error.tryAgain", table: "Home")) {
                        viewStore.receive(action: .loadWords)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("With Words") {
    HomeView(viewStore: .preview, viewState: HomeViewState())
        .preferredColorScheme(.dark)
}

#Preview("Empty State") {
    HomeView(viewStore: .previewEmpty, viewState: HomeViewState())
        .preferredColorScheme(.dark)
}

#Preview("Loading") {
    HomeView(viewStore: .previewLoading, viewState: HomeViewState())
        .preferredColorScheme(.dark)
}

#Preview("Error") {
    HomeView(viewStore: .previewError, viewState: HomeViewState())
        .preferredColorScheme(.dark)
}
#endif

// MARK: - PhaseShimmerModifier

/// A shimmer modifier driven by an externally-provided animation phase.
///
/// Unlike the Shimmer library's built-in `.shimmering()`, which creates a
/// per-cell `@State isInitialState` that resets whenever SwiftUI recycles
/// the view, `PhaseShimmerModifier` is `Animatable` and receives its phase
/// from the parent view. All cells in a `ForEach` share the same animated
/// phase value, so the animation plays continuously and in sync regardless
/// of cell recycling.
///
/// - Parameters:
///   - phase: Animated value from 0 (band off-screen left) to 1 (band off-screen right).
///            Drive this with a `repeatForever(autoreverses: false)` animation on the parent.
///   - isActive: When `false` the modifier is a no-op; content is returned unchanged.
private struct PhaseShimmerModifier: ViewModifier, Animatable {
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    var phase: CGFloat
    let isActive: Bool

    private static let shimmerColors: [Color] = [.clear, .white.opacity(0.55), .clear]

    func body(content: Content) -> some View {
        if isActive {
            content.overlay(
                GeometryReader { geo in
                    let bandWidth = geo.size.width * 0.65
                    let travel = geo.size.width + bandWidth
                    LinearGradient(
                        colors: Self.shimmerColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth)
                    .offset(x: phase * travel - bandWidth)
                    .blendMode(.screen)
                }
                .clipped()
            )
        } else {
            content
        }
    }
}
