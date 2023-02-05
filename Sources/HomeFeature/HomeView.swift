//
//  HomeView.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 9/4/22.
//  Copyright © 2022. All rights reserved.
//

import SwiftUI
import Utilities
import Kingfisher
import SharedModels
import ViewComponents
import SwiftUINavigation
import ComposableArchitecture

public struct HomeView: View {
    let store: StoreOf<HomeReducer>

    public init(
        store: StoreOf<HomeReducer>
    ) {
        self.store = store
    }

    private struct ViewState: Equatable {
        let isLoading: Bool
        let error: HomeReducer.State.Error?

        init(_ state: HomeReducer.State) {
            self.isLoading = state.isLoading
            self.error = state.error
        }
    }

    public var body: some View {
        WithViewStore(
            store,
            observe: ViewState.init
        ) { viewStore in
            Group {
                if let error = viewStore.error {
                    VStack(spacing: 14) {
                        Text(error.title)
                            .font(.body.bold())
                            .foregroundColor(.gray)

                        if let action = error.action {
                            Button {
                                viewStore.send(action.1)
                            } label: {
                                Text(action.0)
                                    .font(.body.weight(.bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.black)
                            .padding(12)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        ExtraTopSafeAreaInset()

                        VStack(spacing: 24) {
                            animeHeroItems(
                                isLoading: viewStore.isLoading,
                                store: store.scope(
                                    state: \.topTrendingAnime
                                )
                            )

                            listAnyEpisodes(
                                title: "Resume Watching",
                                isLoading: viewStore.isLoading,
                                store: store.scope(
                                    state: \.resumeWatching
                                )
                            )

                            animeItemsRepresentable(
                                title: "Last Watched",
                                isLoading: viewStore.isLoading,
                                store: store.scope(
                                    state: \.lastWatchedAnime
                                )
                            )

                            listAnyEpisodes(
                                title: "Recently Updated",
                                isLoading: viewStore.isLoading,
                                store: store.scope(
                                    state: \.recentlyUpdated
                                )
                            )

                            animeItems(
                                title: "Upcoming",
                                isLoading: viewStore.isLoading,
                                store: store.scope(
                                    state: \.topUpcomingAnime
                                )
                            )

                            animeItems(
                                title: "Highest Rated",
                                isLoading: viewStore.isLoading,
                                store: store.scope(
                                    state: \.highestRatedAnime
                                )
                            )

                            animeItems(
                                title: "Most Popular",
                                isLoading: viewStore.isLoading,
                                store: store.scope(
                                    state: \.mostPopularAnime
                                )
                            )
                        }
                        .placeholder(
                            active: viewStore.isLoading,
                            duration:  2.0
                        )
                        .animation(
                            .easeInOut(duration: 0.5),
                            value: viewStore.state
                        )
                        ExtraBottomSafeAreaInset()
                        Spacer(minLength: 32)
                    }
                }
            }
            .animation(
                .easeInOut(duration: 0.5),
                value: viewStore.state
            )
            .disabled(viewStore.isLoading)
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        #if os(iOS)
        .ignoresSafeArea(.container, edges: DeviceUtil.isPhone ? .top : [])
        #endif
    }
}

extension HomeView {
    @ViewBuilder
    var topHeaderView: some View {
        Text("Anime Now!")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }
}

extension HomeView {
    @ViewBuilder
    func animeHero(
        _ anime: Anime
    ) -> some View {
        ZStack(
            alignment: .bottomLeading
        ) {
            FillAspectImage(
                url: (DeviceUtil.isPhone ? anime.posterImage.largest : anime.coverImage.largest ?? anime.posterImage.largest)?.link
            )
            .overlay(
                LinearGradient(
                    stops: [
                        .init(
                            color: .clear,
                            location: 0.4
                        ),
                        .init(
                            color: .black.opacity(0.75),
                            location: 1.0
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(anime.title)
                    .font(.title.weight(.bold))
                    .lineLimit(2)
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
            .padding()
            .padding(.bottom, 24)
        }
    }
}

// MARK: Anime Hero Items

extension HomeView {
    @ViewBuilder
    func animeHeroItems(
        isLoading: Bool,
        store: Store<HomeReducer.LoadableAnime, HomeReducer.Action>
    ) -> some View {
        Group {
            if isLoading {
                animeHero(.placeholder)
            } else {
                WithViewStore(store) { viewStore in
                    if let animes = viewStore.state.value,
                       animes.count > 0 {
                        SnapCarousel(
                            items: animes
                        ) { anime in
                            animeHero(anime)
                                .onTapGesture {
                                    viewStore.send(.animeTapped(anime))
                                }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(DeviceUtil.isPhone ? 5/7 : 6/2, contentMode: .fill)
        .cornerRadius(DeviceUtil.isPhone ? 0 : 32)
        #if os(macOS)
        .padding(.horizontal)
        #endif
    }
}

// MARK: - Animes View

extension HomeView {
    @ViewBuilder
    func animeItems(
        title: String,
        isLoading: Bool,
        store: Store<HomeReducer.LoadableAnime, HomeReducer.Action>
    ) -> some View {
        WithViewStore(
            store,
            observe: { $0 }
        ) { viewStore in
            if let items = isLoading ? Anime.placeholders(5) : viewStore.value, items.count > 0 {
                VStack(alignment: .leading) {
                    headerText(title)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .center, spacing: 12) {
                            ForEach(items) { anime in
                                AnimeItemView(
                                    anime: anime
                                )
                                .onTapGesture {
                                    viewStore.send(.animeTapped(anime))
                                }
                                .disabled(isLoading)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: DeviceUtil.isPhone ? 200 : 275)
                }
            }
        }
    }

    @ViewBuilder
    func animeItemsRepresentable(
        title: String,
        isLoading: Bool,
        store: Store<Loadable<[AnyAnimeRepresentable]>, HomeReducer.Action>
    ) -> some View {
        WithViewStore(
            store,
            observe: { $0 }
        ) { viewStore in
            if let items = isLoading ? Anime.placeholders(5).map { $0.eraseAsRepresentable() } : viewStore.value, items.count > 0 {
                VStack(alignment: .leading) {
                    headerText(title)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .center, spacing: 12) {
                            ForEach(items) { anime in
                                AnimeItemView(
                                    anime: anime
                                )
                                .onTapGesture {
                                    viewStore.send(.anyAnimeTapped(id: anime.id))
                                }
                                .disabled(isLoading)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: DeviceUtil.isPhone ? 200 : 275)
                }
            }
        }
    }

    @ViewBuilder
    var failedToFetchAnimesView: some View {
        VStack(alignment: .center) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.red)
            Text("There seems to be an error fetching shows.")
                .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Episodes View

extension HomeView {
    @ViewBuilder
    func listAnyEpisodes(
        title: String,
        isLoading: Bool,
        store: Store<Loadable<[HomeReducer.AnyWatchAnimeEpisode]>, HomeReducer.Action>
    ) -> some View {
        LoadableViewStore(
            loadable: store
        ) { viewStore in
            if viewStore.count > 0 && !isLoading {
                VStack(alignment: .leading) {
                    headerText(title)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .center) {
                            ForEach(viewStore.state, id: \.id) { item in
                                ThumbnailItemBigView(
                                    episode: item.episode,
                                    animeTitle: item.anime.title,
                                    progress: item.episodeStore?.progress,
                                    progressSize: 6
                                )
                                .frame(height: DeviceUtil.isPhone ? 150 : 225)
                                .onTapGesture {
                                    viewStore.send(.watchEpisodeTapped(item))
                                }
                                .contextMenu {
                                    if item.episodeStore != nil {
                                        Button {
                                            viewStore.send(.markAsWatched(item))
                                        } label: {
                                            Label(
                                                "Mark as Watched",
                                                systemImage: "eye.fill"
                                            )
                                        }
                                    }

                                    Button {
                                        viewStore.send(.anyAnimeTapped(id: item.anime.id))
                                    } label: {
                                        Text("More Details")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

// MARK: - Misc View Helpers

extension HomeView {
    @ViewBuilder
    func headerText(_ title: String) -> some View {
        Text(title)
            .font(DeviceUtil.isPhone ? .headline.bold() : .title2.bold())
            .foregroundColor(.white)
            .padding(.horizontal)
            .opacity(0.9)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            store: .init(
                initialState: .init(
                    topTrendingAnime: .idle,
                    topUpcomingAnime: .idle,
                    highestRatedAnime: .idle,
                    mostPopularAnime: .idle,
                    resumeWatching: .idle,
                    lastWatchedAnime: .idle
                ),
                reducer: HomeReducer()
            )
        )
        .preferredColorScheme(.dark)
    }
}
