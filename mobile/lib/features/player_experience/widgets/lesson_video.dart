import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'experience_widgets.dart';

class LessonVideo extends StatefulWidget {
  const LessonVideo({super.key, required this.asset});
  final String asset;

  @override
  State<LessonVideo> createState() => _LessonVideoState();
}

class _LessonVideoState extends State<LessonVideo>
    with AutomaticKeepAliveClientMixin {
  late final controller = VideoPlayerController.asset(widget.asset);
  late final ready = controller.initialize();
  bool _expanded = true;

  @override
  bool get wantKeepAlive => !_expanded;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    updateKeepAlive();
    if (!_expanded && controller.value.isPlaying) controller.pause();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _toggle() async {
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.isCompleted) await controller.seekTo(Duration.zero);
      if (mounted && _expanded) await controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final label = _expanded ? 'Hide video' : 'Show video';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: TextButton.icon(
            onPressed: _toggleExpanded,
            style: TextButton.styleFrom(
              foregroundColor: mint,
              minimumSize: const Size(0, 44),
            ),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(label),
          ),
        ),
        AnimatedSize(
          alignment: Alignment.topCenter,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: _expanded ? _player(context) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _player(BuildContext context) => FutureBuilder<void>(
    future: ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _error();
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: CupertinoActivityIndicator(),
        );
      }
      final frame = ColoredBox(
        color: Colors.black,
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * .42,
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      );
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        child: frame,
        builder: (context, value, video) {
          if (value.hasError) return _error();
          final action = value.isPlaying
              ? 'Pause'
              : value.isCompleted
              ? 'Replay'
              : 'Play';
          return Column(
            children: [
              GestureDetector(
                excludeFromSemantics: true,
                onTap: _toggle,
                child: video,
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: action,
                    onPressed: _toggle,
                    color: mint,
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause
                          : value.isCompleted
                          ? Icons.replay
                          : Icons.play_arrow,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      semanticFormatterCallback: (ms) =>
                          _time(Duration(milliseconds: ms.round())),
                      activeColor: mint,
                      value: value.position.inMilliseconds
                          .clamp(0, value.duration.inMilliseconds)
                          .toDouble(),
                      max: value.duration.inMilliseconds.toDouble(),
                      onChanged: (ms) =>
                          controller.seekTo(Duration(milliseconds: ms.round())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '${_time(value.position)} / ${_time(value.duration)}',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );

  Widget _error() => const Padding(
    padding: EdgeInsets.all(16),
    child: Text(
      'Video unavailable. You can still read the practice steps below.',
    ),
  );
}
