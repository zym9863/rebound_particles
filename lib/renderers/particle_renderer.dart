import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../models/particle.dart';
import '../models/container.dart';
import '../main.dart';

// 显式导入Flutter的Colors类
import 'package:flutter/material.dart' show Colors;

class ParticleRenderer extends CustomPainter {
  final List<Particle> particles;
  final ParticleContainer container;
  final Particle? hoveredParticle;
  final Particle? selectedParticle;
  final List<Vector3> predictedTrajectory;
  final Vector3? pulseOrigin;
  final double pulseRadius;
  final double pulseAlpha;
  final bool isPulseActive;
  
  ParticleRenderer({
    required this.particles,
    required this.container,
    this.hoveredParticle,
    this.selectedParticle,
    this.predictedTrajectory = const [],
    this.pulseOrigin,
    this.pulseRadius = 0.0,
    this.pulseAlpha = 0.0,
    this.isPulseActive = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 设置画布中心点
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // 保存当前画布状态
    canvas.save();
    
    // 移动到画布中心
    canvas.translate(centerX, centerY);
    
    // 应用容器的变换矩阵
    final matrix = container.getTransformMatrix();
    final scale = container.scaleFactor;
    
    // 绘制外部球形容器（半透明）
    final spherePaint = Paint()
      ..color = container.sphereColor.withOpacity(container.opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2.0);
    
    canvas.drawCircle(
      Offset.zero,
      container.sphereRadius * scale,
      spherePaint,
    );
    
    // 绘制圆柱体容器（半透明虹膜镀层）
    final cylinderPaint = Paint()
      ..shader = container.getIrisGradient().createShader(
        Rect.fromCircle(
          center: Offset.zero,
          radius: container.cylinderRadius * scale,
        ),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 1.5);
    
    // 绘制圆柱体顶部和底部圆形
    final cylinderTopY = -container.cylinderHeight / 2 * scale;
    final cylinderBottomY = container.cylinderHeight / 2 * scale;
    
    // 绘制顶部圆形
    canvas.save();
    canvas.translate(0, cylinderTopY);
    canvas.rotate(container.rotationAngle);
    canvas.drawCircle(
      Offset.zero,
      container.cylinderRadius * scale,
      cylinderPaint,
    );
    canvas.restore();
    
    // 绘制底部圆形
    canvas.save();
    canvas.translate(0, cylinderBottomY);
    canvas.rotate(container.rotationAngle);
    canvas.drawCircle(
      Offset.zero,
      container.cylinderRadius * scale,
      cylinderPaint,
    );
    canvas.restore();
    
    // 绘制圆柱体侧面（两条垂直线）
    for (int i = 0; i < 36; i++) {
      final angle = i * (math.pi / 18);
      final x = container.cylinderRadius * math.cos(angle + container.rotationAngle) * scale;
      final z = container.cylinderRadius * math.sin(angle + container.rotationAngle) * scale;
      
      // 使用渐变效果绘制侧面线条
      final linePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.pulsePurple.withOpacity(container.opacity * 0.7),
            AppColors.quantumBlue.withOpacity(container.opacity),
            AppColors.superCyanTeal.withOpacity(container.opacity * 0.5),
          ],
        ).createShader(Rect.fromPoints(
          Offset(x, cylinderTopY),
          Offset(x, cylinderBottomY),
        ))
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(x, cylinderTopY),
        Offset(x, cylinderBottomY),
        linePaint,
      );
    }
    
    // 绘制底部投影效果（环形离子扩散）
    canvas.save();
    canvas.translate(0, cylinderBottomY);
    canvas.drawCircle(
      Offset.zero,
      container.cylinderRadius * 1.2 * scale,
      container.getBottomShadowPaint(),
    );
    canvas.restore();
    
    // 添加微粒子尘埃效果
    final random = math.Random(42); // 固定种子以保持一致性
    final dustPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;
    
    for (int i = 0; i < 100; i++) {
      final dustX = (random.nextDouble() * 2 - 1) * container.sphereRadius * 1.2 * scale;
      final dustY = (random.nextDouble() * 2 - 1) * container.sphereRadius * 1.2 * scale;
      final dustSize = random.nextDouble() * 1.5;
      
      canvas.drawCircle(
        Offset(dustX, dustY),
        dustSize,
        dustPaint,
      );
    }
    
    // 绘制粒子和轨迹
    for (final particle in particles) {
      // 应用3D变换
      final transformedPosition = matrix.transformed3(Vector3(
        particle.position.x,
        particle.position.y,
        particle.position.z,
      ));
      
      // 计算粒子在2D屏幕上的位置
      final screenX = transformedPosition.x;
      final screenY = transformedPosition.y;
      final screenZ = transformedPosition.z;
      
      // 根据Z坐标调整粒子大小（透视效果）
      // 添加安全检查防止除零错误
      final perspectiveScale = (1000 - screenZ) != 0 ? 1000 / (1000 - screenZ) : 1.0;
      final screenRadius = particle.radius * scale * perspectiveScale;
      
      // 绘制粒子轨迹（拖尾渐隐效果）
      if (particle.trail.length > 1) {
        final path = Path();
        bool isFirstPoint = true;
        
        for (int i = 0; i < particle.trail.length; i++) {
          final trailPoint = particle.trail[i];
          final transformedTrail = matrix.transformed3(Vector3(
            trailPoint.x,
            trailPoint.y,
            trailPoint.z,
          ));
          
          final trailX = transformedTrail.x;
          final trailY = transformedTrail.y;
          
          if (isFirstPoint) {
            path.moveTo(trailX, trailY);
            isFirstPoint = false;
          } else {
            path.lineTo(trailX, trailY);
          }
        }
        
        // 创建轨迹渐变效果
        final trailPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(path.getBounds().left, path.getBounds().top),
            Offset(path.getBounds().right, path.getBounds().bottom),
            [
              particle.color.withOpacity(0.05),
              particle.color.withOpacity(0.2),
              AppColors.superCyanTeal.withOpacity(0.4), // 轨迹高光使用超导青
            ],
            [0.0, 0.7, 1.0],
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
        
        canvas.drawPath(path, trailPaint);
      }
      
      // 绘制电磁斥力光晕
      if (particle.haloRadius > 0) {
        final haloPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              particle.color.withOpacity(0.3),
              particle.color.withOpacity(0.0),
            ],
            stops: const [0.2, 1.0],
          ).createShader(Rect.fromCircle(
            center: Offset(screenX, screenY),
            radius: screenRadius * 2.0,
          ))
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(
          Offset(screenX, screenY),
          particle.haloRadius * scale * perspectiveScale,
          haloPaint,
        );
      }
      
      // 绘制六边形粒子
      final particlePath = Path();
      final sides = particle.sides;
      final particlePaint = Paint()
        ..color = particle.isColliding 
            ? AppColors.superCyanTeal // 碰撞时变色
            : particle.color
        ..style = PaintingStyle.fill
        ..maskFilter = particle.isColliding
            ? const MaskFilter.blur(BlurStyle.outer, 3.0) // 碰撞时添加发光效果
            : null;
      
      // 计算六边形顶点
      for (int i = 0; i < sides; i++) {
        final angle = (i * 2 * math.pi / sides) + math.pi / 6; // 旋转30度使六边形底边水平
        final x = screenX + screenRadius * math.cos(angle);
        final y = screenY + screenRadius * math.sin(angle);
        
        if (i == 0) {
          particlePath.moveTo(x, y);
        } else {
          particlePath.lineTo(x, y);
        }
      }
      particlePath.close();
      
      canvas.drawPath(particlePath, particlePaint);
      
      // 绘制碰撞特效（十二向散射光粒）
      if (particle.isColliding) {
        final effectProgress = 1.0 - (particle.collisionEffectTime / particle.maxCollisionEffectTime);
        final effectPaint = Paint()
          ..color = AppColors.superCyanTeal.withOpacity(0.7 * (1.0 - effectProgress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        
        // 绘制散射光粒
        for (int i = 0; i < 12; i++) {
          final angle = i * math.pi / 6;
          final startRadius = screenRadius * 1.2;
          final endRadius = screenRadius * (2.0 + effectProgress * 2.0);
          
          final startX = screenX + startRadius * math.cos(angle);
          final startY = screenY + startRadius * math.sin(angle);
          final endX = screenX + endRadius * math.cos(angle);
          final endY = screenY + endRadius * math.sin(angle);
          
          canvas.drawLine(
            Offset(startX, startY),
            Offset(endX, endY),
            effectPaint,
          );
        }
      }
    }
    
    // 绘制能量脉冲波
    if (isPulseActive && pulseOrigin != null) {
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.pulsePurple.withOpacity(pulseAlpha * 0.7)
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      
      canvas.drawCircle(
        Offset(pulseOrigin!.x, pulseOrigin!.y),
        pulseRadius,
        pulsePaint,
      );
      
      // 添加内部波纹
      final innerPulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.superCyanTeal.withOpacity(pulseAlpha * 0.5)
        ..strokeWidth = 1.0;
      
      canvas.drawCircle(
        Offset(pulseOrigin!.x, pulseOrigin!.y),
        pulseRadius * 0.7,
        innerPulsePaint,
      );
    }
    
    // 绘制预测轨迹
    if (predictedTrajectory.isNotEmpty && selectedParticle != null) {
      final predictionPath = Path();
      bool isFirstPoint = true;
      
      for (final point in predictedTrajectory) {
        final transformedPoint = matrix.transformed3(point);
        
        if (isFirstPoint) {
          predictionPath.moveTo(transformedPoint.x, transformedPoint.y);
          isFirstPoint = false;
        } else {
          predictionPath.lineTo(transformedPoint.x, transformedPoint.y);
        }
      }
      
      final predictionPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(predictionPath.getBounds().left, predictionPath.getBounds().top),
          Offset(predictionPath.getBounds().right, predictionPath.getBounds().bottom),
          [
            AppColors.superCyanTeal.withOpacity(0.8),
            AppColors.superCyanTeal.withOpacity(0.1),
          ],
          [0.0, 1.0],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);
      
      canvas.drawPath(predictionPath, predictionPaint);
      
      // 在预测轨迹上添加方向箭头
      if (predictedTrajectory.length > 5) {
        for (int i = 5; i < predictedTrajectory.length; i += 10) {
          if (i + 1 < predictedTrajectory.length) {
            final p1 = matrix.transformed3(predictedTrajectory[i]);
            final p2 = matrix.transformed3(predictedTrajectory[i + 1]);
            
            final angle = math.atan2(p2.y - p1.y, p2.x - p1.x);
            final arrowSize = 4.0;
            
            final arrowPath = Path()
              ..moveTo(
                p1.x + arrowSize * math.cos(angle),
                p1.y + arrowSize * math.sin(angle)
              )
              ..lineTo(
                p1.x + arrowSize * math.cos(angle - math.pi * 0.8),
                p1.y + arrowSize * math.sin(angle - math.pi * 0.8)
              )
              ..lineTo(
                p1.x + arrowSize * math.cos(angle + math.pi * 0.8),
                p1.y + arrowSize * math.sin(angle + math.pi * 0.8)
              )
              ..close();
            
            final arrowPaint = Paint()
              ..color = AppColors.superCyanTeal.withOpacity(0.7)
              ..style = PaintingStyle.fill;
            
            canvas.drawPath(arrowPath, arrowPaint);
          }
        }
      }
    }
    
    // 绘制悬停粒子的特殊效果
    if (hoveredParticle != null) {
      final transformedPosition = matrix.transformed3(hoveredParticle!.position);
      final screenX = transformedPosition.x;
      final screenY = transformedPosition.y;
      final screenZ = transformedPosition.z;
      
      // 根据Z坐标调整粒子大小（透视效果）
      final perspectiveScale = 1000 / (1000 - screenZ);
      final screenRadius = hoveredParticle!.radius * container.scaleFactor * perspectiveScale;
      
      // 绘制全息信息框连接线
      final linePaint = Paint()
        ..color = AppColors.quantumBlue.withOpacity(0.6)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        Offset(screenX, screenY),
        Offset(screenX + 30, screenY + 30),
        linePaint,
      );
      
      // 绘制极坐标网格
      final gridPaint = Paint()
        ..color = AppColors.pulsePurple.withOpacity(0.3)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      
      for (int i = 1; i <= 3; i++) {
        canvas.drawCircle(
          Offset(screenX, screenY),
          screenRadius * 1.5 * i,
          gridPaint,
        );
      }
      
      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final lineLength = screenRadius * 4.5;
        
        canvas.drawLine(
          Offset(screenX, screenY),
          Offset(
            screenX + lineLength * math.cos(angle),
            screenY + lineLength * math.sin(angle),
          ),
          gridPaint,
        );
      }
    }
    
    // 恢复画布状态
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // 总是重绘
  }
}