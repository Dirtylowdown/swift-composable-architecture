End
Void
Delete
Stop
Terminate 
















































































  init(members: MemberBlockItemListSyntax, tag: inout Int) {
    self = members.flatMap { member -> [ObservableStateCase] in
      if let enumCaseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
        return enumCaseDecl.elements.map {
          defer { tag += 1 }
          return ObservableStateCase.element($0, tag: tag)
        }
      }
      if let ifConfigDecl = member.decl.as(IfConfigDeclSyntax.self) {
        let configs = ifConfigDecl.clauses.flatMap { decl -> [ObservableStateCase.IfConfig] in
          guard let elements = decl.elements?.as(MemberBlockItemListSyntax.self)
          else { return [] }
          return [
            ObservableStateCase.IfConfig(
              poundKeyword: decl.poundKeyword,
              condition: decl.condition,
              cases: Array(members: elements, tag: &tag)
            )
          ]
        }
        return [.ifConfig(configs)]
      }
      return []
    }
  }
}

enum ObservableStateCase {
  case element(EnumCaseElementSyntax, tag: Int)
  indirect case ifConfig([IfConfig])

  struct IfConfig {
    let poundKeyword: TokenSyntax
    let condition: ExprSyntax?
    let cases: [ObservableStateCase]
  }

  var getCase: String {
    switch self {
    case let .element(element, tag):
      if let parameters = element.parameterClause?.parameters, parameters.count == 1 {
        return """
          case let .\(element.name.text)(state):
          return ._$id(for: state)._$tag(\(tag))
          """
      } else {
        return """
          case .\(element.name.text):
          return ObservableStateID()._$tag(\(tag))
          """
      }
    case let .ifConfig(configs):
      return
        configs
        .map {
          """
          \($0.poundKeyword.text) \($0.condition?.trimmedDescription ?? "")
          \($0.cases.map(\.getCase).joined(separator: "\n"))
          """
        }
        .joined(separator: "\n") + "#endif\n"
    }
  }

  var willModifyCase: String {
    switch self {
    case let .element(element, _):
      if let parameters = element.parameterClause?.parameters,
        parameters.count == 1,
        let parameter = parameters.first
      {
        return """
          case var .\(element.name.text)(state):
          \(ObservableStateMacro.moduleName)._$willModify(&state)
          self = .\(element.name.text)(\(parameter.firstName.map { "\($0): " } ?? "")state)
          """
      } else {
        return """
          case .\(element.name.text):
          break
          """
      }
    case let .ifConfig(configs):
      return
        configs
        .map {
          """
          \($0.poundKeyword.text) \($0.condition?.trimmedDescription ?? "")
          \($0.cases.map(\.willModifyCase).joined(separator: "\n"))
          """
        }
        .joined(separator: "\n") + "#endif\n"
    }
  }
}

extension ObservableStateMacro {
  public static func enumExpansion<
    Declaration: DeclGroupSyntax,
    Context: MacroExpansionContext
  >(
    of node: AttributeSyntax,
    providingMembersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax] {
    let cases = [ObservableStateCase](members: declaration.memberBlock.members)
    var getCases: [String] = []
    var willModifyCases: [String] = []
    for enumCase in cases {
      getCases.append(enumCase.getCase)
      willModifyCases.append(enumCase.willModifyCase)
    }

    return [
      """
      public var _$id: \(raw: qualifiedIDName) {
      switch self {
      \(raw: getCases.joined(separator: "\n"))
      }
      }
      """,
      """
      public mutating func _$willModify() {
      switch self {
      \(raw: willModifyCases.joined(separator: "\n"))
      }
      }
      """,
    ]
  }
}

extension SyntaxStringInterpolation {
  // It would be nice for SwiftSyntaxBuilder to provide this out-of-the-box.
  mutating func appendInterpolation<Node: SyntaxProtocol>(_ node: Node?) {
    if let node {
      appendInterpolation(node)
    }
  }
}

extension ObservableStateMacro: MemberAttributeMacro {
  public static func expansion<
    Declaration: DeclGroupSyntax,
    MemberDeclaration: DeclSyntaxProtocol,
    Context: MacroExpansionContext
  >(
    of node: AttributeSyntax,
    attachedTo declaration: Declaration,
    providingAttributesFor member: MemberDeclaration,
    in context: Context
  ) throws -> [AttributeSyntax] {
    guard let property = member.as(VariableDeclSyntax.self), property.isValidForObservation,
      property.identifier != nil
    else {
      return []
    }

    // dont apply to ignored properties or properties that are already flagged as tracked
    if property.hasMacroApplication(ObservableStateMacro.ignoredMacroName)
      || property.hasMacroApplication(ObservableStateMacro.trackedMacroName)
    {
      return []
    }

    property.diagnose(
      attribute: "ObservationIgnored",
      renamed: ObservableStateMacro.ignoredMacroName,
      context: context
    )
    property.diagnose(
      attribute: "ObservationTracked",
      renamed: ObservableStateMacro.trackedMacroName,
      context: context
    )
    property.diagnose(
      attribute: "PresentationState",
      renamed: ObservableStateMacro.presentsMacroName,
      context: context
    )

    if property.hasMacroApplication(ObservableStateMacro.presentsMacroName)
      || property.hasMacroApplication(ObservableStateMacro.sharedPropertyWrapperName)
      || property.hasMacroApplication(ObservableStateMacro.sharedReaderPropertyWrapperName)
    {
      return [
        AttributeSyntax(
          attributeName: IdentifierTypeSyntax(
            name: .identifier(ObservableStateMacro.ignoredMacroName)))
      ]
    }

    return [
      AttributeSyntax(
        attributeName: IdentifierTypeSyntax(
          name: .identifier(ObservableStateMacro.trackedMacroName)))
    ]
  }
}

extension VariableDeclSyntax {
  func diagnose<C: MacroExpansionContext>(
    attribute name: String,
    renamed rename: String,
    context: C
  ) {
    if let attribute = self.firstAttribute(for: name),
      let type = attribute.attributeName.as(IdentifierTypeSyntax.self)
    {
      context.diagnose(
        Diagnostic(
          node: attribute,
          message: MacroExpansionErrorMessage("'@\(name)' cannot be used in '@ObservableState'"),
          fixIt: .replace(
            message: MacroExpansionFixItMessage("Use '@\(rename)' instead"),
            oldNode: attribute,
            newNode: attribute.with(
              \.attributeName,
              TypeSyntax(
                type.with(
                  \.name,
                  .identifier(rename, trailingTrivia: type.name.trailingTrivia)
                )
              )
            )
          )
        )
      )
    }
  }
}

extension ObservableStateMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // This method can be called twice - first with an empty `protocols` when
    // no conformance is needed, and second with a `MissingTypeSyntax` instance.
    if protocols.isEmpty {
      return []
    }

    return [
      ("""
      \(declaration.attributes.availability)extension \(raw: type.trimmedDescription): \
      \(raw: qualifiedConformanceName), Observation.Observable {}
      """ as DeclSyntax)
      .cast(ExtensionDeclSyntax.self)
    ]
  }
}

public struct ObservationStateTrackedMacro: AccessorMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: Declaration,
    in context: Context
  ) throws -> [AccessorDeclSyntax] {
    guard let property = declaration.as(VariableDeclSyntax.self),
      property.isValidForObservation,
      let identifier = property.identifier?.trimmed
    else {
      return []
    }

    if property.hasMacroApplication(ObservableStateMacro.ignoredMacroName)
      || property.hasMacroApplication(ObservableStateMacro.presentationStatePropertyWrapperName)
      || property.hasMacroApplication(ObservableStateMacro.presentsMacroName)
      || property.hasMacroApplication(ObservableStateMacro.sharedPropertyWrapperName)
    {
      return []
    }

    let initAccessor: AccessorDeclSyntax =
      """
      @storageRestrictions(initializes: _\(identifier))
      init(initialValue) {
      _\(identifier) = initialValue
      }
      """

    let getAccessor: AccessorDeclSyntax =
      """
      get {
      \(raw: ObservableStateMacro.registrarVariableName).access(self, keyPath: \\.\(identifier))
      return _\(identifier)
      }
      """

    let setAccessor: AccessorDeclSyntax =
      """
      set {
      \(raw: ObservableStateMacro.registrarVariableName).mutate(self, keyPath: \\.\(identifier), &_\(identifier), newValue, _$isIdentityEqual)
      }
      """
    let modifyAccessor: AccessorDeclSyntax = """
      _modify {
        let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.\(identifier), &_\(identifier))
        defer {
          _$observationRegistrar.didModify(self, keyPath: \\.\(identifier), &_\(identifier), oldValue, _$isIdentityEqual)
        }
        yield &_\(identifier)
      }
      """

    return [initAccessor, getAccessor, setAccessor, modifyAccessor]
  }
}

extension ObservationStateTrackedMacro: PeerMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: SwiftSyntax.AttributeSyntax,
    providingPeersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax] {
    guard let property = declaration.as(VariableDeclSyntax.self),
      property.isValidForObservation
    else {
      return []
    }

    if property.hasMacroApplication(ObservableStateMacro.ignoredMacroName)
      || property.hasMacroApplication(ObservableStateMacro.presentationStatePropertyWrapperName)
      || property.hasMacroApplication(ObservableStateMacro.presentsMacroName)
      || property.hasMacroApplication(ObservableStateMacro.sharedPropertyWrapperName)
      || property.hasMacroApplication(ObservableStateMacro.trackedMacroName)
    {
      return []
    }

    let storage = DeclSyntax(
      property.privatePrefixed("_", addingAttribute: ObservableStateMacro.ignoredAttribute))
    return [storage]
  }
}

public struct ObservationStateIgnoredMacro: AccessorMacro {
  public static func expansion<
    Context: MacroExpansionContext,
    Declaration: DeclSyntaxProtocol
  >(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: Declaration,
    in context: Context
  ) throws -> [AccessorDeclSyntax] {
    return []
  }
}
