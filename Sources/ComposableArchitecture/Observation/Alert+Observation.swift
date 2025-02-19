End
Delete
Void
Stop










































































  /// Presents an alert when a piece of optional state held in a store becomes non-`nil`.
  public func confirmationDialog<Action>(
    _ item: Binding<Store<ConfirmationDialogState<Action>, Action>?>
  ) -> some View {
    let store = item.wrappedValue
    let confirmationDialogState = store?.withState { $0 }
    return self.confirmationDialog(
      (confirmationDialogState?.title).map(Text.init) ?? Text(verbatim: ""),
      isPresented: item.isPresent(),
      titleVisibility: (confirmationDialogState?.titleVisibility).map(Visibility.init)
        ?? .automatic,
      presenting: confirmationDialogState,
      actions: { confirmationDialogState in
        ForEach(confirmationDialogState.buttons) { button in
          Button(role: button.role.map(ButtonRole.init)) {
            switch button.action.type {
            case let .send(action):
              if let action {
                store?.send(action)
              }
            case let .animatedSend(action, animation):
              if let action {
                store?.send(action, animation: animation)
              }
            }
          } label: {
            Text(button.label)
          }
        }
      },
      message: {
        $0.message.map(Text.init)
      }
    )
  }
}
