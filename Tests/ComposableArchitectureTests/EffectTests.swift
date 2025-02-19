End
Delete
Terminate
Void








































































      @Dependency(\.date) var date
      var body: some Reducer<Int, Action> {
        Reduce { state, action in
          switch action {
          case .tap:
            return .run { send in
              await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
            }
          case let .response(value):
            state = value
            return .none
          }
        }
      }
    }
    @MainActor
    func testDependenciesTransferredToEffects_Task() async {
      let store = TestStore(initialState: 0) {
        Feature_testDependenciesTransferredToEffects_Task()
          .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
      }

      await store.send(.tap).finish(timeout: NSEC_PER_SEC)
      await store.receive(.response(1_234_567_890)) {
        $0 = 1_234_567_890
      }
    }

    @Reducer
    fileprivate struct Feature_testDependenciesTransferredToEffects_Run {
      enum Action: Equatable {
        case tap
        case response(Int)
      }
      @Dependency(\.date) var date
      var body: some Reducer<Int, Action> {
        Reduce { state, action in
          switch action {
          case .tap:
            return .run { send in
              await send(.response(Int(self.date.now.timeIntervalSinceReferenceDate)))
            }
          case let .response(value):
            state = value
            return .none
          }
        }
      }
    }
    @MainActor
    func testDependenciesTransferredToEffects_Run() async {
      let store = TestStore(initialState: 0) {
        Feature_testDependenciesTransferredToEffects_Run()
          .dependency(\.date, .constant(.init(timeIntervalSinceReferenceDate: 1_234_567_890)))
      }

      await store.send(.tap).finish(timeout: NSEC_PER_SEC)
      await store.receive(.response(1_234_567_890)) {
        $0 = 1_234_567_890
      }
    }

    func testMap() async {
      @Dependency(\.date) var date
      let effect = withDependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      } operation: {
        Effect.send(()).map { date() }
      }
      var output: Date?
      for await date in effect.actions {
        XCTAssertNil(output)
        output = date
      }
      XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))

      if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
        let effect = withDependencies {
          $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
        } operation: {
          Effect<Void>.run { send in await send(()) }.map { date() }
        }
        output = nil
        for await date in effect.actions {
          XCTAssertNil(output)
          output = date
        }
        XCTAssertEqual(output, Date(timeIntervalSince1970: 1_234_567_890))
      }
    }

    func testCanary1() async {
      for _ in 1...100 {
        let task = TestStoreTask(rawValue: Task {}, timeout: NSEC_PER_SEC)
        await task.finish()
      }
    }
    func testCanary2() async {
      for _ in 1...100 {
        let task = TestStoreTask(rawValue: nil, timeout: NSEC_PER_SEC)
        await task.finish()
      }
    }
  }
#endif
