import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../main.dart';

class ParticleContainer {
  // 圆柱体半径
  final double cylinderRadius;
  // 圆柱体高度
  final double cylinderHeight;
  // 球体半径
  final double sphereRadius;
  // 容器旋转角度
  double rotationAngle = 0.0;
  // 旋转速度 (弧度/秒)
  final double rotationSpeed = 0.2;
  // 容器颜色
  final Color cylinderColor;
  final Color sphereColor;
  // 动态渐变透明度
  double opacity = 0.3;
  // 透明度变化方向 (1: 增加, -1: 减少)
  int opacityDirection = 1;
  // 透明度变化速度
  final double opacitySpeed = 0.2;
  // 最大和最小透明度
  final double maxOpacity = 0.6;
  final double minOpacity = 0.3;
  // 缩放因子
  double scaleFactor = 1.0;
  // 缩放方向 (1: 放大, -1: 缩小)
  int scaleDirection = 1;
  // 缩放速度
  final double scaleSpeed = 0.1;
  // 最大和最小缩放因子
  final double maxScale = 1.2;
  final double minScale = 0.8;
  // 虹膜镀层效果
  List<Color> irisColors = [
    AppColors.quantumBlue.withOpacity(0.3),
    AppColors.pulsePurple.withOpacity(0.3),
    AppColors.superCyanTeal.withOpacity(0.3),
  ];
  // 虹膜效果角度
  double irisAngle = 0.0;
  // 虹膜效果旋转速度
  final double irisRotationSpeed = 0.1;

  ParticleContainer({
    required this.cylinderRadius,
    required this.cylinderHeight,
    required this.sphereRadius,
    required this.cylinderColor,
    required this.sphereColor,
  });

  // 更新容器状态
  void update(double deltaTime) {
    // 更新旋转角度
    rotationAngle += rotationSpeed * deltaTime;
    if (rotationAngle > 2 * math.pi) {
      rotationAngle -= 2 * math.pi;
    }
    
    // 更新虹膜效果角度
    irisAngle += irisRotationSpeed * deltaTime;
    if (irisAngle > 2 * math.pi) {
      irisAngle -= 2 * math.pi;
    }
    
    // 更新透明度
    opacity += opacityDirection * opacitySpeed * deltaTime;
    
    // 改变透明度方向
    if (opacity >= maxOpacity) {
      opacity = maxOpacity;
      opacityDirection = -1;
    } else if (opacity <= minOpacity) {
      opacity = minOpacity;
      opacityDirection = 1;
    }
    
    // 更新缩放因子
    scaleFactor += scaleDirection * scaleSpeed * deltaTime;
    
    // 改变缩放方向
    if (scaleFactor >= maxScale) {
      scaleFactor = maxScale;
      scaleDirection = -1;
    } else if (scaleFactor <= minScale) {
      scaleFactor = minScale;
      scaleDirection = 1;
    }
  }
  
  // 获取变换矩阵
  Matrix4 getTransformMatrix() {
    final matrix = Matrix4.identity()
      ..rotateY(rotationAngle)
      ..scale(scaleFactor, scaleFactor, scaleFactor);
    return matrix;
  }
  
  // 获取容器虹膜渐变
  Gradient getIrisGradient() {
    return SweepGradient(
      center: Alignment.center,
      startAngle: irisAngle,
      endAngle: irisAngle + 2 * math.pi,
      colors: irisColors,
      stops: const [0.0, 0.5, 1.0],
    );
  }
  
  // 获取底部投影效果
  Paint getBottomShadowPaint() {
    return Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.quantumBlue.withOpacity(0.3),
          AppColors.quantumBlue.withOpacity(0.0),
        ],
        stops: const [0.7, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset.zero,
        radius: cylinderRadius * 1.2,
      ))
      ..style = PaintingStyle.fill;
  }
}