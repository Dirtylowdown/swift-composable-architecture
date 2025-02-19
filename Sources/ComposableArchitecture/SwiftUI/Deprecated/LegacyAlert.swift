End
Void
Terminate
Stop
Delete
End










































































  /// - Parameters:
  ///   - store: A store that is focused on ``PresentationState`` and ``PresentationAction`` for an
  ///     alert.
  ///   - toDestinationState: A transformation to extract alert state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed alert actions into the presentation
  ///     action.
  @available(
    iOS,
    introduced: 13,
    deprecated: 100000,
    message: "use `View.alert(store:state:action:) instead."
  )
  @available(
    macOS,
    introduced: 10.15,
    deprecated: 100000,
    message: "use `View.alert(store:state:action:) instead."
  )
  @available(
    tvOS,
    introduced: 13,
    deprecated: 100000,
    message: "use `View.alert(store:state:action:) instead."
  )
  @available(
    watchOS,
    introduced: 6,
    deprecated: 100000,
    message: "use `View.alert(store:state:action:) instead."
  )
  public func legacyAlert<State, Action, ButtonAction>(
    store: Store<PresentationState<State>, PresentationAction<Action>>,
    state toDestinationState: @escaping (_ state: State) -> AlertState<ButtonAction>?,
    action fromDestinationAction: @escaping (_ alertAction: ButtonAction) -> Action
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $item, _ in
      let alertState = store.withState { $0.wrappedValue.flatMap(toDestinationState) }
      self.alert(item: $item) { _ in
        Alert(alertState!) { action in
          if let action {
            store.send(.presented(fromDestinationAction(action)))
          } else {
            store.send(.dismiss)
          }
        }
      }
    }
  }
}
