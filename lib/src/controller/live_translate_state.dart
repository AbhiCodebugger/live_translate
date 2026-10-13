/// What a live translation view is doing.
enum LiveTranslateState {
  /// The camera is starting, or the controller isn't attached to a view.
  initializing,

  /// The camera is running and lines are being translated live.
  running,

  /// The preview and labels are paused on the current picture.
  frozen,

  /// The camera couldn't start, for example because permission was denied.
  error,
}
