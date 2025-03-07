import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../main.dart';

class Particle {
  // 粒子位置向量
  Vector3 position;
  // 粒子速度向量
  Vector3 velocity;
  // 粒子颜色
  Color color;
  // 粒子半径
  double radius;
  // 粒子轨迹点
  List<Vector3> trail;
  // 轨迹最大长度
  final int maxTrailLength = 30; // 增加轨迹长度
  // 碰撞特效
  bool isColliding = false;
  double collisionEffectTime = 0.0;
  final double maxCollisionEffectTime = 0.3; // 碰撞特效持续时间
  // 电磁斥力光晕
  double haloRadius = 0.0;
  // 粒子形状（六边形）
  final int sides = 6;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
  }) : trail = [position.clone()];

  // 更新粒子位置
  void update(double deltaTime) {
    position += velocity * deltaTime;
    
    // 添加轨迹点
    trail.add(position.clone());
    if (trail.length > maxTrailLength) {
      trail.removeAt(0);
    }
    
    // 更新碰撞特效
    if (isColliding) {
      collisionEffectTime -= deltaTime;
      if (collisionEffectTime <= 0) {
        isColliding = false;
        collisionEffectTime = 0;
      }
    }
    
    // 更新电磁斥力光晕
    final speed = velocity.length;
    haloRadius = radius * (0.8 + speed * 0.01); // 光晕大小随速度变化
  }

  // 检测与圆柱体的碰撞
  void checkCylinderCollision(double cylinderRadius, double cylinderHeight) {
    // 检测与圆柱侧面的碰撞
    final horizontalPosition = Vector2(position.x, position.z);
    final horizontalDistance = horizontalPosition.length;
    
    if (horizontalDistance + radius > cylinderRadius) {
      // 计算法线向量
      final normal = Vector2(position.x, position.z).normalized();
      
      // 调整位置，防止穿透
      final penetrationDepth = horizontalDistance + radius - cylinderRadius;
      position.x -= normal.x * penetrationDepth;
      position.z -= normal.y * penetrationDepth;
      
      // 计算水平速度分量
      final horizontalVelocity = Vector2(velocity.x, velocity.z);
      
      // 计算反射速度
      final dot = horizontalVelocity.dot(normal);
      horizontalVelocity.x -= 2 * dot * normal.x;
      horizontalVelocity.y -= 2 * dot * normal.y;
      
      // 更新速度
      velocity.x = horizontalVelocity.x;
      velocity.z = horizontalVelocity.y;
    }
    
    // 检测与圆柱顶部和底部的碰撞
    if (position.y + radius > cylinderHeight / 2) {
      position.y = cylinderHeight / 2 - radius;
      velocity.y = -velocity.y;
    } else if (position.y - radius < -cylinderHeight / 2) {
      position.y = -cylinderHeight / 2 + radius;
      velocity.y = -velocity.y;
    }
  }
  
  // 检测与球体的碰撞
  void checkSphereCollision(double sphereRadius) {
    final distance = position.length;
    
    if (distance + radius > sphereRadius) {
      // 计算法线向量
      final normal = position.normalized();
      
      // 调整位置，防止穿透
      final penetrationDepth = distance + radius - sphereRadius;
      position -= normal * penetrationDepth;
      
      // 计算反射速度
      final dot = velocity.dot(normal);
      velocity -= normal * (2 * dot);
    }
  }
  
  // 检测与其他粒子的碰撞
  void checkParticleCollision(Particle other) {
    final distanceVector = position - other.position;
    final distance = distanceVector.length;
    final minDistance = radius + other.radius;
    
    if (distance < minDistance) {
      // 计算法线向量
      final normal = distanceVector.normalized();
      
      // 计算相对速度
      final relativeVelocity = velocity - other.velocity;
      final velocityAlongNormal = relativeVelocity.dot(normal);
      
      // 如果粒子正在远离，则不处理碰撞
      if (velocityAlongNormal > 0) return;
      
      // 计算冲量
      final restitution = 0.8; // 弹性系数
      final impulseMagnitude = -(1 + restitution) * velocityAlongNormal / 2;
      
      // 应用冲量
      velocity += normal * impulseMagnitude;
      other.velocity -= normal * impulseMagnitude;
      
      // 调整位置，防止穿透
      final penetrationDepth = minDistance - distance;
      position += normal * (penetrationDepth / 2);
      other.position -= normal * (penetrationDepth / 2);
      
      // 触发碰撞特效
      isColliding = true;
      other.isColliding = true;
      collisionEffectTime = maxCollisionEffectTime;
      other.collisionEffectTime = maxCollisionEffectTime;
    }
  }
}