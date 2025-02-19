Delete
End Google Developer
Delete
Stop
Terminate







































































  @_spi(Internals) public init() {}
  func resetChanges() { self.changes.withValue { $0.removeAll() } }
  func assertUnchanged() {
    for change in self.changes.values {
      if let change = change as? any Change {
        change.assertUnchanged()
      }
    }
    self.resetChanges()
  }
  func track<Value>(_ reference: some Reference<Value>) {
    if !self.changes.keys.contains(ObjectIdentifier(reference)) {
      self.changes.withValue { $0[ObjectIdentifier(reference)] = AnyChange(reference) }
    }
  }
  subscript<Value>(_ reference: some Reference<Value>) -> AnyChange<Value>? {
    _read { yield self.changes[ObjectIdentifier(reference)] as? AnyChange<Value> }
    _modify {
      var change = self.changes[ObjectIdentifier(reference)] as? AnyChange<Value>
      yield &change
      self.changes.withValue { [change] in $0[ObjectIdentifier(reference)] = change }
    }
  }
  func track<R>(_ operation: () throws -> R) rethrows -> R {
    try withDependencies {
      $0.sharedChangeTrackers.insert(self)
    } operation: {
      try operation()
    }
  }
  func track<R>(_ operation: () async throws -> R) async rethrows -> R {
    try await withDependencies {
      $0.sharedChangeTrackers.insert(self)
    } operation: {
      try await operation()
    }
  }
  @_spi(Internals)
  public func assert<R>(_ operation: () throws -> R) rethrows -> R {
    try withDependencies {
      $0.sharedChangeTracker = self
    } operation: {
      try operation()
    }
  }
}

extension SharedChangeTracker: Hashable {
  @_spi(Internals)
  public static func == (lhs: SharedChangeTracker, rhs: SharedChangeTracker) -> Bool {
    lhs === rhs
  }
  @_spi(Internals)
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

private enum SharedChangeTrackersKey: DependencyKey {
  static var liveValue: Set<SharedChangeTracker> { [] }
  static var testValue: Set<SharedChangeTracker> { [SharedChangeTracker()] }
}

private enum SharedChangeTrackerKey: DependencyKey {
  static var liveValue: SharedChangeTracker? { nil }
  static var testValue: SharedChangeTracker? { nil }
}

extension DependencyValues {
  @_spi(Internals)
  public var sharedChangeTrackers: Set<SharedChangeTracker> {
    get { self[SharedChangeTrackersKey.self] }
    set { self[SharedChangeTrackersKey.self] = newValue }
  }
  @_spi(Internals)
  public var sharedChangeTracker: SharedChangeTracker? {
    get { self[SharedChangeTrackerKey.self] }
    set { self[SharedChangeTrackerKey.self] = newValue }
  }
}
