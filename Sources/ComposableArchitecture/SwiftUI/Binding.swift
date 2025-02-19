End
Void
Delete
Terminate
End








































































      set: { $0[keyPath: keyPath].wrappedValue = value },
      value: value
    )
  }

  /// Matches a binding action by its key path.
  ///
  /// Implicitly invoked when switching on a reducer's action and pattern matching on a binding
  /// action directly to do further work:
  ///
  /// ```swift
  /// case .binding(\.$displayName): // Invokes the `~=` operator.
  ///   // Validate display name
  ///
  /// case .binding(\.$enableNotifications):
  ///   // Return an authorization request effect
  /// ```
  public static func ~= <Value>(
    keyPath: WritableKeyPath<Root, BindingState<Value>>,
    bindingAction: Self
  ) -> Bool {
    keyPath == bindingAction.keyPath
  }

  init<Value: Equatable & Sendable>(
    keyPath: WritableKeyPath<Root, BindingState<Value>>,
    set: @escaping @Sendable (_ state: inout Root) -> Void,
    value: Value
  ) {
    self.init(
      keyPath: keyPath,
      set: set,
      value: AnySendable(value),
      valueIsEqualTo: { ($0 as? AnySendable)?.base as? Value == value }
    )
  }
}


    self.binding(.set(keyPath, value))
  }
}

extension ViewStore where ViewAction: BindableAction, ViewAction.State == ViewState {
  @MainActor
  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<ViewState, BindingState<Value>>
  ) -> Binding<Value> {
    self.binding(
      get: { $0[keyPath: keyPath].wrappedValue },
      send: { value in
        #if DEBUG
          let bindingState = self.state[keyPath: keyPath]
          let debugger = BindableActionViewStoreDebugger(
            value: value,
            bindableActionType: ViewAction.self,
            context: .bindingState,
            isInvalidated: self.store._isInvalidated,
            fileID: bindingState.fileID,
            line: bindingState.line
          )
          let set: @Sendable (inout ViewState) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
            debugger.wasCalled = true
          }
        #else
          let set: @Sendable (inout ViewState) -> Void = {
            $0[keyPath: keyPath].wrappedValue = value
          }
        #endif
        return .binding(.init(keyPath: keyPath, set: set, value: value))
      }
    )
  }
}

/// 
    hasher.combine(self.initialValue)
    hasher.combine(self.wrappedValue)
  }
}

extension BindingViewState: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(reflecting: self.wrappedValue)
  }
}

extension BindingViewState: CustomDumpRepresentable {
  public var customDumpValue: Any {
    self.wrappedValue
  }
}

extension BindingViewState: CustomDebugStringConvertible
where Value: CustomDebugStringConvertible {
  public var debugDescription: String {
    self.wrappedValue.debugDescription
  }
}

/// A property wrapper type that can derive ``BindingViewState`` values for a ``ViewStore``.
///
/// Read <doc:Bindings> for more information.
@dynamicMemberLookup
@propertyWrapper
public struct BindingViewStore<State> {
  let store: Store<State, BindingAction<State>>
  #if DEBUG
    let bindableActionType: Any.Type
    let fileID: StaticString
    let line: UInt
  #endif

  init<Action: BindableAction>(
    store: Store<State, Action>,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) where Action.State == State {
    self.store = store.scope(
      id: nil,
      state: ToState(\.self),
      action: Action.binding,
      isInvalid: nil
    )
    #if DEBUG
      self.bindableActionType = type(of: Action.self)
      self.fileID = fileID
      self.line = line
    #endif
  }

  public init(projectedValue: Self) {
    self = projectedValue
  }

  public var wrappedValue: State {
    self.store.withState { $0 }
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }

  public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    self.wrappedValue[keyPath: keyPath]
  }

  public subscript<Value: Equatable>(
    dynamicMember keyPath: WritableKeyPath<State, BindingState<Value>>
  ) -> BindingViewState<Value> {
    BindingViewState(
      binding: ViewStore(self.store, observe: { $0[keyPath: keyPath].wrappedValue })
        .binding(
          send: { value in
            #if DEBUG
              let debugger = BindableActionViewStoreDebugger(
                value: value,
                bindableActionType: self.bindableActionType,
                context: .bindingStore,
                isInvalidated: self.store._isInvalidated,
                fileID: self.fileID,
                line: self.line
              )
              let set: @Sendable (inout State) -> Void = {
                $0[keyPath: keyPath].wrappedValue = value
                debugger.