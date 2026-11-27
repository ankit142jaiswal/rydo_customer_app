import 'package:flutter/material.dart';
import 'app_colors.dart';

/// A bookable service. [type] matches the backend `serviceType` value.
class RydoService {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String price;
  const RydoService(this.type, this.title, this.subtitle, this.icon, this.color, this.price);
}

/// A group of services shown together (Ride, Parcel, Goods).
class ServiceCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<RydoService> services;
  const ServiceCategory(this.id, this.title, this.subtitle, this.icon, this.services);
}

class ServiceCatalog {
  static const categories = <ServiceCategory>[
    ServiceCategory('ride', 'Ride', 'Get where you need to go', Icons.person_pin_circle_rounded, [
      RydoService('bike-taxi', 'Bike Taxi', 'Quick short rides', Icons.two_wheeler_rounded, AppColors.bikeTaxi, 'From ₹25'),
      RydoService('auto', 'Auto', 'Comfortable rides', Icons.electric_rickshaw_rounded, AppColors.auto, 'From ₹40'),
    ]),
    ServiceCategory('parcel', 'Parcel', 'Send packages across the city', Icons.inventory_2_rounded, [
      RydoService('courier', 'Courier', 'Send packages fast', Icons.inventory_2_rounded, AppColors.courier, 'From ₹20'),
    ]),
    ServiceCategory('goods', 'Goods Transport', 'Move furniture and bulk goods', Icons.local_shipping_rounded, [
      RydoService('mini-truck', 'Mini Truck', 'Small loads & shifting', Icons.local_shipping_rounded, AppColors.miniTruck, 'From ₹100'),
      RydoService('truck', 'Truck', 'Large loads', Icons.fire_truck_rounded, AppColors.truck, 'From ₹200'),
    ]),
  ];

  static List<RydoService> get all => [for (final c in categories) ...c.services];

  static ServiceCategory categoryOf(String type) =>
      categories.firstWhere((c) => c.services.any((s) => s.type == type), orElse: () => categories.first);

  static RydoService? byType(String type) {
    for (final s in all) {
      if (s.type == type) return s;
    }
    return null;
  }
}
