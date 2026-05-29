import 'package:flutter/material.dart';

class SlideToAnswer extends StatefulWidget {
  final VoidCallback onAnswer;
  final String text;

  const SlideToAnswer({
    super.key,
    required this.onAnswer,
    this.text = 'slide to answer',
  });

  @override
  State<SlideToAnswer> createState() => _SlideToAnswerState();
}

class _SlideToAnswerState extends State<SlideToAnswer>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(_animController)
      ..addListener(() {
        setState(() {
          _dragPosition = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_animController.isAnimating) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details, double maxDrag) {
    if (_animController.isAnimating) return;
    
    // Jika digeser lebih dari 85%, panggil onAnswer
    if (_dragPosition >= maxDrag * 0.85) {
      setState(() {
        _dragPosition = maxDrag;
      });
      widget.onAnswer();
    } else {
      // Kembalikan ke posisi semula secara halus dengan animasi pegas
      _animation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
      );
      _animController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        const buttonSize = 56.0;
        final maxDrag = containerWidth - buttonSize - 8.0; // padding 4.0 di kiri-kanan

        return Container(
          width: containerWidth,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Teks petunjuk di latar belakang
              Center(
                child: Opacity(
                  opacity: ((maxDrag - _dragPosition) / maxDrag).clamp(0.2, 1.0),
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Tombol geser meluncur
              Positioned(
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _onDragUpdate(details, maxDrag),
                  onHorizontalDragEnd: (details) =>
                      _onDragEnd(details, maxDrag),
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
