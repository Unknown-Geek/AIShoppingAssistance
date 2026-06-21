import 'dart:ui';
import 'package:flutter/material.dart';

class GradualBlur extends StatelessWidget {
  final double strength;
  final int divCount;
  final double height;
  final Alignment begin;
  final Alignment end;

  const GradualBlur({
    super.key,
    this.strength = 15.0,
    this.divCount = 5,
    this.height = 40.0,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Stack(
          children: List.generate(divCount, (index) {
            final double progress = (index + 1) / divCount;
            final double blurValue = progress * strength;
            
            final double start = index / divCount;
            final double endVal = progress;

            return Positioned.fill(
              child: ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: begin,
                    end: end,
                    colors: const [
                      Colors.transparent,
                      Colors.black,
                    ],
                    stops: [
                      start,
                      endVal,
                    ],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
