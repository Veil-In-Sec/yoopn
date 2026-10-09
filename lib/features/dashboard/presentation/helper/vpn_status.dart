enum VpnStatus {
  disconnected('Not protected', 'Tap to secure your connection'),
  connecting('Connecting...', 'Establishing a secure tunnel'),
  connected('You are protected', 'Your traffic is encrypted');

  const VpnStatus(this.title, this.subtitle);

  final String title;
  final String subtitle;
}