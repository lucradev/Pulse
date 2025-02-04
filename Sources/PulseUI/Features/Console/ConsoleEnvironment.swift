// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

/// Contains every dependency that the console views have.
///
/// - warning: It's marked with `ObservableObject` to make it possible to be used
/// with `@StateObject` and `@EnvironmentObject`, but it never changes.
final class ConsoleEnvironment: ObservableObject {
    let title: String
    let store: LoggerStore
    let index: LoggerStoreIndex

    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    let logCountObserver: ManagedObjectsCountObserver
    let taskCountObserver: ManagedObjectsCountObserver

    let router = ConsoleRouter()

    let initialMode: ConsoleMode

    @Published var mode: ConsoleMode

    var bindingForNetworkMode: Binding<Bool> {
        Binding(get: {
            self.mode == .network
        }, set: {
            self.mode = $0 ? .network : .all
        })
    }

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, mode: ConsoleMode = .all) {
        self.store = store
        switch mode {
        case .all: self.title = "Console"
        case .logs: self.title = "Logs"
        case .network: self.title = "Network"
        }
        self.initialMode = mode
        self.mode = mode

        func makeDefaultOptions() -> ConsolePredicateOptions {
            var options = ConsolePredicateOptions()
            options.criteria.shared.sessions.selection = [store.session.id]
            return options
        }

        self.index = LoggerStoreIndex(store: store)
        self.searchCriteriaViewModel = ConsoleSearchCriteriaViewModel(options: makeDefaultOptions(), index: index)

        self.logCountObserver = ManagedObjectsCountObserver(
            entity: LoggerMessageEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)
        )

        self.taskCountObserver = ManagedObjectsCountObserver(
            entity: NetworkTaskEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(keyPath: \NetworkTaskEntity.createdAt, ascending: false)
        )

        bind()
    }

    private func bind() {
        $mode.sink { [weak self] in
            self?.searchCriteriaViewModel.mode = $0
        }.store(in: &cancellables)

        searchCriteriaViewModel.$options.sink { [weak self] in
            self?.refreshCountObservers($0)
        }.store(in: &cancellables)
    }

    private func refreshCountObservers(_ options: ConsolePredicateOptions) {
        func makePredicate(for mode: ConsoleMode) -> NSPredicate? {
            ConsoleDataSource.makePredicate(mode: mode, options: options)
        }
        logCountObserver.setPredicate(makePredicate(for: .logs))
        taskCountObserver.setPredicate(makePredicate(for: .network))
    }

    func removeAllLogs() {
        store.removeAll()
        index.clear()


#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All messages removed")
            }
        }.show()
#endif
    }
}

public enum ConsoleMode: String {
    /// Displays both messages and network tasks with the ability
    /// to switch between the two modes.
    case all
    /// Displays only regular messages.
    case logs
    /// Displays only network tasks.
    case network
}

// MARK: Environment

private struct LoggerStoreKey: EnvironmentKey {
    static let defaultValue: LoggerStore = .shared
}

private struct ConsoleRouterKey: EnvironmentKey {
    static let defaultValue: ConsoleRouter = .init()
}

extension EnvironmentValues {
    var store: LoggerStore {
        get { self[LoggerStoreKey.self] }
        set { self[LoggerStoreKey.self] = newValue }
    }

    var router: ConsoleRouter {
        get { self[ConsoleRouterKey.self] }
        set { self[ConsoleRouterKey.self] = newValue }
    }
}

extension View {
    func injecting(_ environment: ConsoleEnvironment) -> some View {
        self.background(ConsoleRouterView()) // important: order
            .environmentObject(environment)
            .environmentObject(environment.router)
            .environmentObject(environment.index)
            .environment(\.router, environment.router)
            .environment(\.store, environment.store)
            .environment(\.managedObjectContext, environment.store.viewContext)
    }
}
