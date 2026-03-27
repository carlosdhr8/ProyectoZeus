import 'dart:math';
import 'package:latlong2/latlong.dart';

class GeometryUtils {
  /// Douglas-Peucker Algorithm to simplify a path
  static List<LatLng> simplifyPath(List<LatLng> points, double tolerance) {
    if (points.length <= 2) return points;

    int index = -1;
    double maxDist = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double dist = _perpendicularDistance(points[i], points.first, points.last);
      if (dist > maxDist) {
        index = i;
        maxDist = dist;
      }
    }

    if (maxDist > tolerance) {
      List<LatLng> left = simplifyPath(points.sublist(0, index + 1), tolerance);
      List<LatLng> right = simplifyPath(points.sublist(index), tolerance);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points.first, points.last];
    }
  }

  static double _perpendicularDistance(LatLng p, LatLng start, LatLng end) {
    double x = p.longitude;
    double y = p.latitude;
    double x1 = start.longitude;
    double y1 = start.latitude;
    double x2 = end.longitude;
    double y2 = end.latitude;

    double numerator = ((y2 - y1) * x - (x2 - x1) * y + x2 * y1 - y2 * x1).abs();
    double denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2));
    return numerator / denominator;
  }

  /// Catmull-Rom Spline Interpolation
  static List<LatLng> smoothPath(List<LatLng> points, {int segments = 5}) {
    if (points.length < 4) return points;

    List<LatLng> smoothed = [];
    // Add artificial control points at the ends to stay within range
    List<LatLng> controlPoints = [
      _extrapolate(points[1], points[0]),
      ...points,
      _extrapolate(points[points.length - 2], points.last),
    ];

    for (int i = 0; i < controlPoints.length - 3; i++) {
      for (int t = 0; t <= segments; t++) {
        smoothed.add(_catmullRom(
            controlPoints[i],
            controlPoints[i + 1],
            controlPoints[i + 2],
            controlPoints[i + 3],
            t / segments));
      }
    }
    return smoothed;
  }

  static LatLng _catmullRom(LatLng p0, LatLng p1, LatLng p2, LatLng p3, double t) {
    double t2 = t * t;
    double t3 = t2 * t;

    double f1 = -0.5 * t3 + t2 - 0.5 * t;
    double f2 = 1.5 * t3 - 2.5 * t2 + 1.0;
    double f3 = -1.5 * t3 + 2.0 * t2 + 0.5 * t;
    double f4 = 0.5 * t3 - 0.5 * t2;

    return LatLng(
      p0.latitude * f1 + p1.latitude * f2 + p2.latitude * f3 + p3.latitude * f4,
      p0.longitude * f1 + p1.longitude * f2 + p2.longitude * f3 + p3.longitude * f4,
    );
  }

  static LatLng _extrapolate(LatLng p1, LatLng p2) {
    return LatLng(
      p2.latitude + (p2.latitude - p1.latitude),
      p2.longitude + (p2.longitude - p1.longitude),
    );
  }

  /// Calculate bearing/angle between two coordinates in radians
  static double calculateAngle(LatLng start, LatLng end) {
    double dy = end.latitude - start.latitude;
    double dx = end.longitude - start.longitude;
    return atan2(dy, dx);
  }
}
