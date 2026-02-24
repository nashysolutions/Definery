//
//  HomeViewState.swift
//  Definery
//
//  Created by Anthony on 3/1/26.
//
import SwiftUI
import Observation

import WordFeature
import ScreenStateKit

@MainActor @Observable
final class HomeViewState: LoadmoreScreenState, StateUpdatable {
    var words: [Word] = Word.mocks
    var selectedLanguage: Locale.LanguageCode = .english
    var isPlaceholder: Bool = true

    var hasWords: Bool { !words.isEmpty && !isPlaceholder }
    var hasError: Bool { displayError?.errorDescription != nil }
}

// MARK: - PlaceholderRepresentable

extension HomeViewState: PlaceholderRepresentable {
    static var placeholder: HomeViewState {
        HomeViewState()
    }
}
