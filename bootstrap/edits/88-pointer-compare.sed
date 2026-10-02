# reason: (д) the modern compiler. Pointers of two different object types are compared (PFilePanel, the descendant,
# with PFilePanelRoot): TP/VP allow it, FPC wants one of them to be a plain Pointer. Only the places the compiler named.
s/(IV^\.Panel = ActivePanel)/(Pointer(IV^.Panel) = Pointer(ActivePanel))/
