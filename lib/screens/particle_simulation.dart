import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../models/particle.dart';
import '../models/container.dart';
import '../renderers/particle_renderer.dart';
import '../main.dart';

class ParticleSimulation extends StatefulWidget {
  const ParticleSimulation({super.key});

  @override
  State<ParticleSimulation> createState() => _ParticleSimulationState();
}

class _ParticleSimulationState extends State<ParticleSimulation>
    with SingleTickerProviderStateMixin {
  // 平台检测
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  // 动画控制器
  late AnimationController _controller;
  
  // 粒子列表
  final List<Particle> _particles = [];
  
  // 容器
  late ParticleContainer _container;
  
  // 上一帧时间
  late DateTime _lastFrameTime;
  
  // 随机数生成器
  final _random = math.Random();
  
  // 粒子数量
  final int _particleCount = 25;
  
  // 交互状态
  Particle? _hoveredParticle;
  Particle? _selectedParticle;
  Vector3? _pulseOrigin;
  double _pulseRadius = 0.0;
  double _pulseMaxRadius = 200.0;
  double _pulseAlpha = 0.0;
  bool _isPulseActive = false;
  
  // 预测轨迹点
  List<Vector3> _predictedTrajectory = [];
  
  @override
  void initState() {
    super.initState();
    
    // 初始化容器
    _container = ParticleContainer(
      cylinderRadius: 100.0,
      cylinderHeight: 200.0,
      sphereRadius: 150.0,
      cylinderColor: AppColors.quantumBlue,
      sphereColor: AppColors.pulsePurple,
    );
    
    // 初始化粒子
    _initParticles();
    
    // 初始化动画控制器
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    
    // 记录当前时间
    _lastFrameTime = DateTime.now();
    
    // 启动动画
    _controller.repeat();
    _controller.addListener(_updateSimulation);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  // 初始化粒子
  void _initParticles() {
    // 清空粒子列表
    _particles.clear();
    
    // 创建量子色彩列表
    final colors = [
      AppColors.quantumBlue,
      AppColors.pulsePurple,
      AppColors.superCyanTeal,
      AppColors.quantumBlue.withOpacity(0.8),
      AppColors.pulsePurple.withOpacity(0.8),
      AppColors.superCyanTeal.withOpacity(0.8),
    ];
    
    // 创建粒子
    for (int i = 0; i < _particleCount; i++) {
      // 随机位置（在圆柱体内）
      final radius = _random.nextDouble() * _container.cylinderRadius * 0.8;
      final angle = _random.nextDouble() * 2 * math.pi;
      final height = _random.nextDouble() * _container.cylinderHeight - _container.cylinderHeight / 2;
      
      final position = Vector3(
        radius * math.cos(angle),
        height,
        radius * math.sin(angle),
      );
      
      // 随机速度
      final speed = 20.0 + _random.nextDouble() * 30.0;
      final velocityAngle = _random.nextDouble() * 2 * math.pi;
      final velocityHeight = -0.5 + _random.nextDouble();
      
      final velocity = Vector3(
        speed * math.cos(velocityAngle),
        speed * velocityHeight,
        speed * math.sin(velocityAngle),
      );
      
      // 随机半径
      final particleRadius = 3.0 + _random.nextDouble() * 3.0;
      
      // 创建粒子
      final particle = Particle(
        position: position,
        velocity: velocity,
        color: colors[i % colors.length],
        radius: particleRadius,
      );
      
      _particles.add(particle);
    }
  }
  
  // 更新模拟
  void _updateSimulation() {
    // 计算时间增量
    final now = DateTime.now();
    final deltaTime = now.difference(_lastFrameTime).inMilliseconds / 1000.0;
    _lastFrameTime = now;
    
    // 更新容器
    _container.update(deltaTime);
    
    // 更新粒子
    for (final particle in _particles) {
      // 更新位置
      particle.update(deltaTime);
      
      // 检测与容器的碰撞
      particle.checkCylinderCollision(
        _container.cylinderRadius,
        _container.cylinderHeight,
      );
      
      particle.checkSphereCollision(_container.sphereRadius);
    }
    
    // 检测粒子之间的碰撞
    for (int i = 0; i < _particles.length; i++) {
      for (int j = i + 1; j < _particles.length; j++) {
        _particles[i].checkParticleCollision(_particles[j]);
      }
    }
    
    // 更新能量脉冲波
    if (_isPulseActive) {
      _pulseRadius += 150.0 * deltaTime; // 脉冲扩散速度
      _pulseAlpha = 1.0 - (_pulseRadius / _pulseMaxRadius);
      
      if (_pulseRadius >= _pulseMaxRadius) {
        _isPulseActive = false;
        _pulseRadius = 0.0;
        _pulseAlpha = 0.0;
      }
    }
    
    // 触发重绘
    setState(() {});
  }
  
  // 处理点击事件
  void _handleTap(TapDownDetails details) {
    // 获取点击位置
    final tapPosition = details.localPosition;
    final centerX = MediaQuery.of(context).size.width / 2;
    final centerY = MediaQuery.of(context).size.height / 2;
    
    // 转换为相对于中心的坐标
    final relativeX = tapPosition.dx - centerX;
    final relativeY = tapPosition.dy - centerY;
    
    // 创建能量脉冲波
    _pulseOrigin = Vector3(relativeX, relativeY, 0);
    _pulseRadius = 0.0;
    _pulseAlpha = 1.0;
    _isPulseActive = true;
    
    // 选择最近的粒子
    Particle? closestParticle;
    double minDistance = double.infinity;
    
    for (final particle in _particles) {
      // 应用容器的变换矩阵
      final matrix = _container.getTransformMatrix();
      final transformedPosition = matrix.transformed3(particle.position);
      
      // 计算屏幕位置
      final screenX = transformedPosition.x + centerX;
      final screenY = transformedPosition.y + centerY;
      
      // 计算与点击位置的距离
      final distance = math.sqrt(math.pow(screenX - tapPosition.dx, 2) + 
                               math.pow(screenY - tapPosition.dy, 2));
      
      if (distance < minDistance) {
        minDistance = distance;
        closestParticle = particle;
      }
    }
    
    // 如果找到最近的粒子，生成预测轨迹
    if (closestParticle != null && minDistance < 50) {
      _selectedParticle = closestParticle;
      _generateTrajectoryPrediction(_selectedParticle!, 1.5); // 1.5秒的预测轨迹
      
      // 在移动设备上，保持选中状态直到下一次点击
      if (!_isMobile) {
        // 在桌面设备上，1.5秒后清除预测轨迹
        Future.delayed(const Duration(milliseconds: 1500), () {
          setState(() {
            _predictedTrajectory.clear();
            _selectedParticle = null;
          });
        });
      }
    }
  }
  
  // 处理悬停事件
  void _handleHover(PointerHoverEvent event) {
    // 获取悬停位置
    final hoverPosition = event.localPosition;
    final centerX = MediaQuery.of(context).size.width / 2;
    final centerY = MediaQuery.of(context).size.height / 2;
    
    // 查找悬停的粒子
    _hoveredParticle = null;
    
    for (final particle in _particles) {
      // 应用容器的变换矩阵
      final matrix = _container.getTransformMatrix();
      final transformedPosition = matrix.transformed3(particle.position);
      
      // 计算屏幕位置
      final screenX = transformedPosition.x + centerX;
      final screenY = transformedPosition.y + centerY;
      
      // 计算与悬停位置的距离
      final distance = math.sqrt(math.pow(screenX - hoverPosition.dx, 2) + 
                               math.pow(screenY - hoverPosition.dy, 2));
      
      // 如果距离小于粒子半径的2倍，认为悬停在粒子上
      if (distance < particle.radius * 2) {
        _hoveredParticle = particle;
        break;
      }
    }
    
    setState(() {});
  }
  
  // 生成轨迹预测
  void _generateTrajectoryPrediction(Particle particle, double duration) {
    _predictedTrajectory.clear();
    
    // 创建粒子的副本用于预测
    final predictionParticle = Particle(
      position: particle.position.clone(),
      velocity: particle.velocity.clone(),
      color: particle.color,
      radius: particle.radius,
    );
    
    // 模拟未来的运动
    final steps = 60; // 预测步数
    final timeStep = duration / steps;
    
    for (int i = 0; i < steps; i++) {
      // 更新位置
      predictionParticle.position += predictionParticle.velocity * timeStep;
      
      // 检测与容器的碰撞
      predictionParticle.checkCylinderCollision(
        _container.cylinderRadius,
        _container.cylinderHeight,
      );
      
      predictionParticle.checkSphereCollision(_container.sphereRadius);
      
      // 添加预测点
      _predictedTrajectory.add(predictionParticle.position.clone());
    }
    
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSpaceBlack,
      body: _isMobile
          ? GestureDetector(
              onTapDown: _handleTap,
              child: _buildSimulationContent(context),
            )
          : MouseRegion(
              onHover: _handleHover,
              child: GestureDetector(
                onTapDown: _handleTap,
                child: _buildSimulationContent(context),
              ),
            ),
    );
  }
  
  // 构建模拟内容
  Widget _buildSimulationContent(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          // 粒子模拟
          CustomPaint(
            painter: ParticleRenderer(
              particles: _particles,
              container: _container,
              hoveredParticle: _hoveredParticle,
              selectedParticle: _selectedParticle,
              predictedTrajectory: _predictedTrajectory,
              pulseOrigin: _pulseOrigin,
              pulseRadius: _pulseRadius,
              pulseAlpha: _pulseAlpha,
              isPulseActive: _isPulseActive,
            ),
            size: Size.infinite,
          ),
          
          // 粒子信息显示 - 在移动设备上显示选中的粒子信息，在桌面设备上显示悬停的粒子信息
          if (_isMobile ? _selectedParticle != null : _hoveredParticle != null)
            Positioned(
              left: 20,
              bottom: 20,
              child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.darkSpaceBlack.withOpacity(0.7),
                        border: Border.all(color: AppColors.quantumBlue, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '量子粒子数据',
                            style: TextStyle(
                              color: AppColors.superCyanTeal,
                              fontFamily: 'Orbitron',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildParticleInfoRow('位置', 
                            'X: ${(_isMobile ? _selectedParticle! : _hoveredParticle!).position.x.toStringAsFixed(1)} ' 
                            'Y: ${(_isMobile ? _selectedParticle! : _hoveredParticle!).position.y.toStringAsFixed(1)} ' 
                            'Z: ${(_isMobile ? _selectedParticle! : _hoveredParticle!).position.z.toStringAsFixed(1)}'),
                          _buildParticleInfoRow('速度', 
                            '${(_isMobile ? _selectedParticle! : _hoveredParticle!).velocity.length.toStringAsFixed(1)} 单位/秒'),
                          _buildParticleInfoRow('方向', 
                            '${(math.atan2((_isMobile ? _selectedParticle! : _hoveredParticle!).velocity.z, (_isMobile ? _selectedParticle! : _hoveredParticle!).velocity.x) * 180 / math.pi).toStringAsFixed(1)}°'),
                          _buildParticleInfoRow('能量', 
                            '${((_isMobile ? _selectedParticle! : _hoveredParticle!).velocity.length * (_isMobile ? _selectedParticle! : _hoveredParticle!).radius).toStringAsFixed(1)} 焦耳'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
  
  // 构建粒子信息行
  Widget _buildParticleInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: AppColors.pulsePurple.withOpacity(0.7),
              fontFamily: 'Orbitron',
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.quantumBlue.withOpacity(0.7),
              fontFamily: 'Orbitron',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}