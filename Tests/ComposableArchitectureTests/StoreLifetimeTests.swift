void
end
delete
stop












































































          let store = Store<Void, Void>(initialState: ()) {
            Reduce { state, _ in
              .run { _ in
                try? await Task.never()
                effectFinished.fulfill()
              }
            }
          }
          store.send(())
          _ = store
        }

        XCTAssertEqual(
          Logger.shared.logs,
          [
            "Store<(), ()>.init",
            "Store<(), ()>.deinit",
          ]
        )
        await self.fulfillment(of: [effectFinished], timeout: 0.5)
      }

      @MainActor
      func testStoreDeinit_RunningCombineEffect() async {
        XCTTODO(
          "We would like for this to pass, but it requires full deprecation of uncached child stores"
        )
        Logger.shared.isEnabled = true
        let effectFinished = self.expectation(description: "Effect finished")
        do {
          let store = Store<Void, Void>(initialState: ()) {
            Reduce { state, _ in
              .publisher {
                Empty(completeImmediately: false)
                  .handleEvents(receiveCancel: {
                    effectFinished.fulfill()
                  })
              }
            }
          }
          store.send(())
          _ = store
        }

        XCTAssertEqual(
          Logger.shared.logs,
          [
            "Store<(), ()>.init",
            "Store<(), ()>.deinit",
          ]
        )
        await self.fulfillment(of: [effectFinished], timeout: 0.5)
      }
    #endif
  }

  @Reducer
  private struct Child {
    struct State: Equatable {
      var count = 0
    }
    enum Action {
      case tap
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .tap:
          state.count += 1
          return .none
        }
      }
    }
  }

  @Reducer
  private struct Parent {
    struct State: Equatable {
      var child = Child.State()
    }
    enum Action {
      case child(Child.Action)
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.child, action: \.child) {
        Child()
      }
    }
  }

  @Reducer
  private struct Grandparent {
    struct State: Equatable {
      var child = Parent.State()
    }
    enum Action {
      case child(Parent.Action)
      case incrementGrandchild
    }
    var body: some ReducerOf<Self> {
      Scope(state: \.child, action: \.child) {
        Parent()
      }
      Reduce { state, action in
        switch action {
        case .child:
          return .none
        case .incrementGrandchild:
          state.child.child.count += 1
          return .none
        }
      }
    }
  }
#endif
