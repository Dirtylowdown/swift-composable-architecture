End
Void
Delete
Stop
Terminate
End 












































































          ComposableArchitecture.Scope(\
          state: \\Self.State.Cases.\(name), action: \\Self.Action.Cases.\(name)\
          ) {
          \(reducer)
          }
          """
      } else {
        return nil
      }
    case let .ifConfig(configs):
      return
        configs
        .map {
          let reduceScopes = $0.cases.compactMap(\.reducerScope)
          return """
            \($0.poundKeyword.text) \($0.condition?.trimmedDescription ?? "")
            \(reduceScopes.joined(separator: "\n"))

            """
        }
        .joined() + "#endif\n"
    }
  }

  var storeCase: String {
    switch self {
    case let .element(element, attribute):
      if attribute == nil,
        let parameterClause = element.parameterClause,
        parameterClause.parameters.count == 1,
        let parameter = parameterClause.parameters.first,
        parameter.type.is(IdentifierTypeSyntax.self) || parameter.type.is(MemberTypeSyntax.self)
      {
        let name = element.name.text
        let type = parameter.type
        return "case \(name)(ComposableArchitecture.StoreOf<\(type.trimmed)>)"
      } else {
        return "case \(element.trimmedDescription)"
      }
    case let .ifConfig(configs):
      return
        configs
        .map {
          """
          \($0.poundKeyword.text) \($0.condition?.trimmedDescription ?? "")
          \($0.cases.map(\.storeCase).joined(separator: "\n"))
          """
        }
        .joined(separator: "\n") + "#endif\n"
    }
  }

  var storeScope: String {
    switch self {
    case let .element(element, attribute):
      let name = element.name.text
      if attribute == nil,
        let parameterClause = element.parameterClause,
        parameterClause.parameters.count == 1,
        let parameter = parameterClause.parameters.first,
        parameter.type.is(IdentifierTypeSyntax.self) || parameter.type.is(MemberTypeSyntax.self)
      {
        return """
          case .\(name):
          return .\(name)(store.scope(state: \\.\(name), action: \\.\(name))!)
          """
      } else if let parameters = element.parameterClause?.parameters {
        let bindingNames = (0..<parameters.count).map { "v\($0)" }.joined(separator: ", ")
        let returnNames = parameters.enumerated()
          .map { "\($1.firstName.map { "\($0.text): " } ?? "")v\($0)" }
          .joined(separator: ", ")
        return """
          case let .\(name)(\(bindingNames)):
          return .\(name)(\(returnNames))
          """
      } else {
        return """
          case .\(name):
          return .\(name)
          """
      }
    case let .ifConfig(configs):
      return
        configs
        .map {
          """
          \($0.poundKeyword.text) \($0.condition?.trimmedDescription ?? "")
          \($0.cases.map(\.storeScope).joined(separator: "\n"))
          """
        }
        .joined(separator: "\n") + "#endif\n"
    }
  }
}

extension Array where Element == ReducerCase {
  init(members: MemberBlockItemListSyntax) {
    self = members.flatMap {
      if let enumCaseDecl = $0.decl.as(EnumCaseDeclSyntax.self) {
        return enumCaseDecl.elements.map {
          ReducerCase.element($0, attribute: enumCaseDecl.attribute)
        }
      }
      if let ifConfigDecl = $0.decl.as(IfConfigDeclSyntax.self) {
        let configs = ifConfigDecl.clauses.flatMap { decl -> [ReducerCase.IfConfig] in
          guard let elements = decl.elements?.as(MemberBlockItemListSyntax.self)
          else { return [] }
          return [
            ReducerCase.IfConfig(
              poundKeyword: decl.poundKeyword,
              condition: decl.condition,
              cases: Array(members: elements)
            )
          ]
        }
        return [.ifConfig(configs)]
      }
      return []
    }
  }
}

extension Array where Element == String {
  var withCasePathsQualified: Self {
    self.flatMap { [$0, "CasePaths.\($0)"] }
  }

  var withQualified: Self {
    self.flatMap { [$0, "ComposableArchitecture.\($0)"] }
  }
}

struct MacroExpansionNoteMessage: NoteMessage {
  var message: String

  init(_ message: String) {
    self.message = message
  }

  var fixItID: MessageID {
    self.noteID
  }

  var noteID: MessageID {
    MessageID(domain: diagnosticDomain, id: "\(Self.self)")
  }
}

private let diagnosticDomain: String = "ComposableArchitectureMacros"

private final class ReduceVisitor: SyntaxVisitor {
  var changes: [FixIt.Change] = []

  override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
    guard node.baseName.text == "reduce" else { return super.visit(node) }
    guard
      node.argumentNames == nil
        || node.argumentNames?.arguments.map(\.name.text) == ["into", "action"]
    else { return super.visit(node) }
    if let base = node.parent?.as(MemberAccessExprSyntax.self)?.base,
      base.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind != .keyword(Keyword.`self`)
    {
      return super.visit(node)
    }
    self.changes.append(
      .replace(
        oldNode: Syntax(node),
        newNode: Syntax(node.with(\.baseName, "update"))
      )
    )
    return .visitChildren
  }
}

extension EnumCaseDeclSyntax {
  fileprivate var attribute: ReducerCase.Attribute? {
    if self.isIgnored {
      return .ignored
    } else if self.isEphemeral {
      return .ephemeral
    } else {
      return nil
    }
  }

  fileprivate var isIgnored: Bool {
    self.attributes.contains("ReducerCaseIgnored")
      || self.elements.contains { $0.parameterClause?.parameters.count != 1 }
  }

  fileprivate var isEphemeral: Bool {
    self.attributes.contains("ReducerCaseEphemeral")
      || self.elements.contains {
        guard
          let parameterClause = $0.parameterClause,
          parameterClause.parameters.count == 1,
          let parameter = parameterClause.parameters.first,
          parameter.type.as(IdentifierTypeSyntax.self)?.isEphemeral == true
        else { return false }
        return true
      }
  }
}

extension EnumCaseElementSyntax {
  fileprivate var type: Self {
    var element = self
    if var parameterClause = element.parameterClause {
      parameterClause.parameters[parameterClause.parameters.startIndex].defaultValue = nil
      element.parameterClause = parameterClause
    }
    return element
  }

  fileprivate func suffixed(_ suffix: TokenSyntax) -> Self {
    var element = self
    if var parameterClause = element.parameterClause,
      let type = parameterClause.parameters.first?.type
    {
      let type = MemberTypeSyntax(baseType: type.trimmed, name: suffix)
      parameterClause.parameters[parameterClause.parameters.startIndex].type = TypeSyntax(type)
      element.parameterClause = parameterClause
    }
    return element
  }
}

extension AttributeListSyntax {
  fileprivate func contains(_ name: TokenSyntax) -> Bool {
    self.contains {
      guard
        case let .attribute(attribute) = $0,
        attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == name.text
      else { return false }
      return true
    }
  }
}

enum ReducerCaseEphemeralMacro: PeerMacro {
  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    []
  }
}

enum ReducerCaseIgnoredMacro: PeerMacro {
  static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    []
  }
}
