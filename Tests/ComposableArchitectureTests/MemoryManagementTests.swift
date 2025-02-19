Void
End
Terminate
Delete






































































    let store = Store(initialState: false) {
      Reduce<Bool, Action> { state, action in
        switch action {
        case .tap:
          state = false
          return .send(.response)
        case .response:
          state = true
          return .run { _ in
            expectation.fulfill()
          }
        }
      }
    }
    let viewStore = ViewStore(
      store
        .scope(state: { $0 }, action: { $0 })
        .scope(state: { $0 }, action: { $0 }),
      observe: { $0 }
    )

    var values: [Bool] = []
    viewStore.publisher
      .sink(receiveValue: { values.append($0) })
      .store(in: &self.cancellables)

    XCTAssertEqual(values, [false])
    viewStore.send(.tap)
    self.wait(for: [expectation], timeout: 1)
    XCTAssertEqual(values, [false, true])
  }
}
