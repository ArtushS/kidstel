enum StoryImageStatus { none, loading, ready, error }

class StoryImageState {
  final StoryImageStatus status;
  final String? url;
  final String? error;

  const StoryImageState._({
    required this.status,
    required this.url,
    required this.error,
  });

  const StoryImageState.none()
    : this._(status: StoryImageStatus.none, url: null, error: null);

  const StoryImageState.loading()
    : this._(status: StoryImageStatus.loading, url: null, error: null);

  const StoryImageState.ready(String url)
    : this._(status: StoryImageStatus.ready, url: url, error: null);

  const StoryImageState.failed(String error)
    : this._(status: StoryImageStatus.error, url: null, error: error);

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'url': url,
    'error': error,
  };

  factory StoryImageState.fromJson(Map<String, dynamic> json) {
    final statusName = (json['status'] ?? 'none').toString();
    final status = StoryImageStatus.values.cast<StoryImageStatus>().firstWhere(
      (e) => e.name == statusName,
      orElse: () => StoryImageStatus.none,
    );

    final url = json['url'] as String?;
    final error = json['error'] as String?;

    switch (status) {
      case StoryImageStatus.none:
        return const StoryImageState.none();
      case StoryImageStatus.loading:
        return const StoryImageState.loading();
      case StoryImageStatus.ready:
        return url != null && url.isNotEmpty
            ? StoryImageState.ready(url)
            : const StoryImageState.none();
      case StoryImageStatus.error:
        return StoryImageState.failed(error ?? 'Unknown error');
    }
  }
}
