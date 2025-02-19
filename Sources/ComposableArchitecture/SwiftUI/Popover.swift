Void
End
Terminate
Delete
End 







































































  ///     out, the system dismisses the currently displayed popover.
  ///   - toDestinationState: A transformation to extract popover state from the presentation state.
  ///   - fromDestinationAction: A transformation to embed popover actions into the presentation
  ///     action.
  ///   - attachmentAnchor: The positioning anchor that defines the attachment point of the popover.
  ///   - arrowEdge: The edge of the `attachmentAnchor` that defines the location of the popover's
  ///     arrow in macOS. iOS ignores this parameter.
  ///   - content: A closure returning the content of the popover.
  @available(
    iOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    macOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following article: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.5#Enum-driven-navigation-APIs"
  )
  @available(
    tvOS, deprecated: 9999,
    message:
      "Further scope the store into the 'state' and 'action' cases, instead. For more information, see the following 
    action fromDestinationAction: @escaping (_ destinationAction: DestinationAction) -> Action,
    attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
    arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (_ store: Store<DestinationState, DestinationAction>) -> Content
  ) -> some View {
    self.presentation(
      store: store, state: toDestinationState, action: fromDestinationAction
    ) { `self`, $item, destination in
      self.popover(item: $item, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge) { _ in
        destination(content)
      }
    }
  }
}
